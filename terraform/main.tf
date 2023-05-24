//################################################################################
//# Locals
//################################################################################
locals {
  region       = "eu-west-1"
  project_name = "testground"
  environment  = "tg"
  vpc_cidr     = "10.1"
  azs          = ["${local.region}a", "${local.region}b", "${local.region}c"]
}

################################################################################
# VPC Module
################################################################################
module "vpc" {
  source = "github.com/terraform-aws-modules/terraform-aws-vpc?ref=v3.19.0"

  name = "${local.project_name}-${local.environment}"
  cidr = "${local.vpc_cidr}.0.0/16"

  //azs = ["${local.region}a", "${local.region}b", "${local.region}c"]
  azs = local.azs

  // TODO: check this in future, could be the issue about networking :/
  private_subnets = ["${local.vpc_cidr}.0.0/20", "${local.vpc_cidr}.16.0/20", "${local.vpc_cidr}.32.0/20"]
  intra_subnets   = ["${local.vpc_cidr}.48.0/20", "${local.vpc_cidr}.64.0/20", "${local.vpc_cidr}.80.0/20"]
  public_subnets  = ["${local.vpc_cidr}.96.0/20", "${local.vpc_cidr}.112.0/20", "${local.vpc_cidr}.128.0/20"]

  enable_dns_hostnames   = true
  enable_nat_gateway     = true
  single_nat_gateway     = true
  one_nat_gateway_per_az = false
  //one_nat_gateway_per_az = false

  tags = {
    Terraform   = "true"
    Createdby   = "Terraform"
    Environment = "${local.environment}"
  }

  vpc_tags = {
    Name = "${local.project_name}-${local.environment}"
  }

  public_subnet_tags = {
    "kubernetes.io/role/elb"                                           = "1"
    "kubernetes.io/cluster/${local.project_name}-${local.environment}" = "shared"
  }

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = "1"
  }
}

################################################################################
# EKS Cluster - Blueprints Module
################################################################################
module "eks_blueprints" {
  source = "github.com/aws-ia/terraform-aws-eks-blueprints?ref=v4.25.0"

  # EKS CLUSTER
  cluster_name       = "${local.project_name}-${local.environment}-eks"
  cluster_version    = "1.26"
  vpc_id             = module.vpc.vpc_id
  public_subnet_ids  = module.vpc.public_subnets
  private_subnet_ids = module.vpc.private_subnets

  cluster_endpoint_private_access = true
  cluster_endpoint_public_access  = true

  // TODO: want to test
  // enable_irsa                     = true

  // https://github.com/aws-ia/terraform-aws-eks-blueprints/issues/619
  node_security_group_additional_rules = {
    # Extend node-to-node security group rules. Recommended and required for the Add-ons
    ingress_self_all = {
      description = "Node to node all ports/protocols"
      protocol    = "-1"
      from_port   = 0
      to_port     = 0
      type        = "ingress"
      self        = true
    }
    # Recommended outbound traffic for Node groups
    egress_all = {
      description      = "Node all egress"
      protocol         = "-1"
      from_port        = 0
      to_port          = 0
      type             = "egress"
      cidr_blocks      = ["0.0.0.0/0"]
      ipv6_cidr_blocks = ["::/0"]
    }
    # Allows Control Plane Nodes to talk to Worker nodes on all ports. Added this to simplify the example and further avoid issues with Add-ons communication with Control plane.
    # This can be restricted further to specific port based on the requirement for each Add-on e.g., metrics-server 4443, spark-operator 8080, karpenter 8443 etc.
    # Change this according to your security requirements if needed
    ingress_cluster_to_node_all_traffic = {
      description              = "Cluster API to Nodegroup all traffic"
      protocol                 = "-1"
      from_port                = 0
      to_port                  = 0
      type                     = "ingress"
      source_security_group_id = module.eks_blueprints.cluster_security_group_id
    }
  }

  # List of map_users
  # define your list of users here
  # Example:
  # map_users = [
  #   {
  #     userarn  = "arn:aws:iam::<your-account-id>:user/<user-id>"
  #     username = "<username>"
  #     groups   = ["system:masters"]
  #   }
  # ]
  map_users = [
    {
      userarn  = "arn:aws:iam::*:user/*"
      username = "*"
      groups   = ["system:masters"]
    }
  ]

  # EKS MANAGED NODE GROUPS
  managed_node_groups = {
    ng-1-infra = {
      node_group_name = "ng-1-infra"
      instance_types  = ["c5.4xlarge"]

      subnet_ids    = module.vpc.private_subnets
      capacity_type = "ON_DEMAND"
      disk_size     = 30
      k8s_labels = {
        "testground.node.role.infra" = "true"
      }

      # Node Group scaling configuration
      max_size     = 10
      min_size     = 3
      desired_size = 3

      create_launch_template = true
      kubelet_extra_args     = "--use-max-pods=false --max-pods=58"
      bootstrap_extra_args   = "--use-max-pods=false --max-pods=58 --container-runtime docker"
      bootstrap_extra_args   = ""
      pre_userdata = <<-EOT
      sudo bash -c 'cat <<SYSCTL > /etc/sysctl.d/999-testground.conf
      fs.file-max = 3178504
      net.core.somaxconn = 131072
      net.netfilter.nf_conntrack_max = 1048576
      net.core.netdev_max_backlog = 524288
      net.core.rmem_max = 16777216
      net.core.wmem_max = 16777216
      net.ipv4.tcp_rmem = 16384 131072 16777216
      net.ipv4.tcp_wmem = 16384 131072 16777216
      net.ipv4.tcp_mem = 262144 524288 1572864
      net.ipv4.tcp_max_syn_backlog = 131072
      net.ipv4.ip_local_port_range = 10000 65535
      net.ipv4.tcp_tw_reuse = 1
      net.ipv4.ip_forward = 1
      net.ipv4.conf.all.rp_filter = 0
      net.ipv4.neigh.default.gc_thresh2 = 4096
      net.ipv4.neigh.default.gc_thresh3 = 32768
      SYSCTL'
      sudo sysctl -p /etc/sysctl.d/999-testground.conf
      sudo bash -c 'cat <<LIMITS > /etc/security/limits.d/999-limits.conf
      * soft nproc 131072
      * hard nproc 262144
      * soft nofile 131072
      * hard nofile 262144
      LIMITS'
      EOT
    },
    ng-2-plan = {
      node_group_name = "ng-2-plan"
      instance_types  = ["c5.4xlarge"]

      subnet_ids    = module.vpc.private_subnets
      capacity_type = "ON_DEMAND"
      disk_size     = 30
      k8s_labels = {
        "testground.node.role.plan" = "true"
      }

      # Node Group scaling configuration
      max_size     = 10
      min_size     = 2
      desired_size = 2

      create_launch_template = true
      kubelet_extra_args     = "--max-pods=234 --allowed-unsafe-sysctls=net.core.somaxconn --use-max-pods=false"
      bootstrap_extra_args     = "--use-max-pods=false --max-pods=58 --container-runtime docker"

      pre_userdata = <<-EOT
      sudo bash -c 'cat <<SYSCTL > /etc/sysctl.d/999-testground.conf
      fs.file-max = 3178504
      net.core.somaxconn = 131072
      net.netfilter.nf_conntrack_max = 1048576
      net.core.netdev_max_backlog = 524288
      net.core.rmem_max = 16777216
      net.core.wmem_max = 16777216
      net.ipv4.tcp_rmem = 16384 131072 16777216
      net.ipv4.tcp_wmem = 16384 131072 16777216
      net.ipv4.tcp_mem = 262144 524288 1572864
      net.ipv4.tcp_max_syn_backlog = 131072
      net.ipv4.ip_local_port_range = 10000 65535
      net.ipv4.tcp_tw_reuse = 1
      net.ipv4.ip_forward = 1
      net.ipv4.conf.all.rp_filter = 0
      net.ipv4.neigh.default.gc_thresh2 = 4096
      net.ipv4.neigh.default.gc_thresh3 = 32768
      SYSCTL'
      sudo sysctl -p /etc/sysctl.d/999-testground.conf"
      sudo bash -c 'cat <<LIMITS > /etc/security/limits.d/999-limits.conf
      * soft nproc 131072
      * hard nproc 262144
      * soft nofile 131072
      * hard nofile 262144
      LIMITS'
      EOT
    }
  }

  cluster_security_group_additional_rules = {
    ingress_from_vpc = {
      description = "Allow inbound traffic from VPC CIDR"
      protocol    = "-1"
      from_port   = 0
      to_port     = 0
      type        = "ingress"
      cidr_blocks = [module.vpc.vpc_cidr_block]
    }
  }

  tags = {
    Terraform   = "true"
    Createdby   = "Terraform"
    Environment = "${local.environment}"
  }
}

################################################################################
# SG
################################################################################
resource "aws_security_group_rule" "allow_node_sg_to_cluster_sg" {
  description = "Self-Node Group to Cluster API/MNG all traffic"

  source_security_group_id = module.eks_blueprints.worker_node_security_group_id
  security_group_id        = module.eks_blueprints.cluster_primary_security_group_id
  type                     = "ingress"
  protocol                 = "-1"
  from_port                = 0
  to_port                  = 0

  depends_on = [
    module.eks_blueprints
  ]
}

resource "aws_security_group_rule" "allow_node_sg_from_cluster_sg" {
  description              = "Cluster API/MNG to Self-Nodegroup all traffic"
  source_security_group_id = module.eks_blueprints.cluster_primary_security_group_id
  security_group_id        = module.eks_blueprints.worker_node_security_group_id
  type                     = "ingress"
  protocol                 = "-1"
  from_port                = 0
  to_port                  = 0

  depends_on = [
    module.eks_blueprints
  ]
}
################################################################################
# EKS Addons
################################################################################
module "eks_blueprints_kubernetes_addons" {
  source = "github.com/aws-ia/terraform-aws-eks-blueprints//modules/kubernetes-addons?ref=v4.29.0"

  eks_cluster_id       = module.eks_blueprints.eks_cluster_id
  eks_cluster_endpoint = module.eks_blueprints.eks_cluster_endpoint
  eks_oidc_provider    = module.eks_blueprints.oidc_provider
  eks_cluster_version  = module.eks_blueprints.eks_cluster_version

  # EKS Addons
  enable_amazon_eks_vpc_cni            = true
  enable_amazon_eks_coredns            = true
  enable_amazon_eks_kube_proxy         = true
  enable_amazon_eks_aws_ebs_csi_driver = true
  enable_aws_efs_csi_driver            = true

  #K8s Add-ons
  enable_metrics_server               = true
  enable_cluster_autoscaler           = true
  enable_aws_load_balancer_controller = true

  enable_argocd         = true
  argocd_manage_add_ons = true
  argocd_applications = {
    addons = {
      path               = "chart"
      repo_url           = "https://github.com/aws-samples/eks-blueprints-add-ons.git"
      add_on_application = true # Indicates the root add-on application.
    }

    // https://github.com/aws-ia/terraform-aws-eks-blueprints/blob/main/modules/kubernetes-addons/argocd/main.tf#L94-L114
    kustomize-apps = {
      path            = "argocd-root"
      repo_url        = "https://github.com/testground/infra.git"
      target_revision = "v0.7.0"
      type            = "kustomize"
    }
  }

  argocd_helm_config = {
    values = [templatefile("${path.module}/argocd-values.yaml", {})]
  }
}

################################################################################
# S3
################################################################################
// https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket
resource "aws_s3_bucket" "bucket" {
  bucket = "${local.project_name}-${local.environment}"
  acl    = "private"

  versioning {
    enabled = true
  }
}
