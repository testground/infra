locals {
  region       = "eu-west-1"
  project_name = "celestia"
  environment  = "testground"
  vpc_cidr     = "10.1"
}

################################################################################
# Import sysrex KeyPair
################################################################################
resource "aws_key_pair" "sysrex" {
  key_name   = "sysrex"
  public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQClLZmoDMTa1Rnd2XcFs5UUb7EGr6vBj2aYUZLM0IiTVHdFzEz2sZBnRpP2SvnN0FuD3dSN36TRZnB1W9yoWwFU5qfg59bwnfC5EaEVLLcg5cmH0bd3FMC3TA1431jlrnRFvdl2f1vQQAA9Ja7kjCBGv+3yA7gof4ZSAROIYompv/3Cpnm++ega8y5Tds9UqnNZY+vganv/91vbO3xim4hfiTCPNfuqgL1Zr6bV4jxBeQrofpg9jISmRE8jXqIh0xt47FKv7aRq6IGOlS1Rzzwma6+uFXobR2gbRxaYp8n8tNsWFRke/5TLJuldiMRXfA8nDrJNVllBk+zyMNOKSHOh alex@sysrex.com"
}

################################################################################
# VPC Module
################################################################################

module "vpc" {
  source = "github.com/terraform-aws-modules/terraform-aws-vpc?ref=v3.19.0"

  name = "${local.project_name}-${local.environment}"
  cidr = "${local.vpc_cidr}.0.0/16"

  azs = ["${local.region}a", "${local.region}b", "${local.region}c"]

  private_subnets = ["${local.vpc_cidr}.0.0/20", "${local.vpc_cidr}.16.0/20", "${local.vpc_cidr}.32.0/20"]
  intra_subnets   = ["${local.vpc_cidr}.48.0/20", "${local.vpc_cidr}.64.0/20", "${local.vpc_cidr}.80.0/20"]
  public_subnets  = ["${local.vpc_cidr}.96.0/20", "${local.vpc_cidr}.112.0/20", "${local.vpc_cidr}.128.0/20"]

  enable_dns_hostnames   = true
  enable_nat_gateway     = true
  single_nat_gateway     = true
  one_nat_gateway_per_az = false


  tags = {
    Terraform   = "true"
    Createdby   = "sysrex"
    Environment = "${local.environment}"
  }

  vpc_tags = {
    Name = "${local.project_name}-${local.environment}"
  }

  public_subnet_tags = {
    "kubernetes.io/role/elb" = "1"
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
  cluster_version    = "1.25"
  vpc_id             = module.vpc.vpc_id
  public_subnet_ids  = module.vpc.public_subnets
  private_subnet_ids = module.vpc.private_subnets

  cluster_endpoint_private_access = "true"
  cluster_endpoint_public_access  = "true"



  # List of map_users
  map_users = [
    {
      userarn  = "arn:aws:iam::506657148836:user/samuel@celestia.org"
      username = "samuel@celestia.org"
      groups   = ["system:masters"]
    },
    {
      userarn  = "arn:aws:iam::506657148836:user/viet@celestia.org"
      username = "viet@celestia.org"
      groups   = ["system:masters"]
    },
    {
      userarn  = "arn:aws:iam::506657148836:user/alexk@celestia.org"
      username = "alexk@celestia.org"
      groups   = ["system:masters"]
    },
    {
      userarn  = "arn:aws:iam::506657148836:user/jose@celestia.org"
      username = "jose@celestia.org"
      groups   = ["system:masters"]
    }
  ]

  # EKS MANAGED NODE GROUPS
  managed_node_groups = {
    ng-1-infra = {
      node_group_name = "ng-1-infra"
      instance_types  = ["c5a.xlarge"]
      subnet_ids      = module.vpc.private_subnets
      capacity_type   = "ON_DEMAND"
      disk_size       = 30
      k8s_labels      = {
        "testground.node.role.infra" = "true"
      }
      //remote_access = true
      //ec2_ssh_key   = "sysrex"

      # Node Group scaling configuration
      max_size     = 80
      min_size     = 3
      desired_size = 3
  
     create_launch_template = true
     kubelet_extra_args     = "--use-max-pods=false --max-pods=58"
     //bootstrap_extra_args   = ""
      //pre_userdata = <<-EOT
      //sudo bash -c 'cat <<SYSCTL > /etc/sysctl.d/999-testground.conf
      //fs.file-max = 3178504
      //net.core.somaxconn = 131072
      //net.netfilter.nf_conntrack_max = 1048576
      //net.core.netdev_max_backlog = 524288
      //net.core.rmem_max = 16777216
      //net.core.wmem_max = 16777216
      //net.ipv4.tcp_rmem = 16384 131072 16777216
      //net.ipv4.tcp_wmem = 16384 131072 16777216
      //net.ipv4.tcp_mem = 262144 524288 1572864
      //net.ipv4.tcp_max_syn_backlog = 131072
      //net.ipv4.ip_local_port_range = 10000 65535
      //net.ipv4.tcp_tw_reuse = 1
      //net.ipv4.ip_forward = 1
      //net.ipv4.conf.all.rp_filter = 0
      //net.ipv4.neigh.default.gc_thresh2 = 4096
      //net.ipv4.neigh.default.gc_thresh3 = 32768
      //SYSCTL'
      //sudo sysctl -p /etc/sysctl.d/999-testground.conf
      //sudo bash -c 'cat <<LIMITS > /etc/security/limits.d/999-limits.conf
      //* soft nproc 131072
      //* hard nproc 262144
      //* soft nofile 131072
      //* hard nofile 262144
      //LIMITS'
      //EOT

//      iam:
// attachPolicyARNs:
// - arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryFullAccess
// - arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy
// - arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly
// - arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore
// - arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy
    },
    ng-2-plan = {
      node_group_name = "ng-2-plan"
      instance_types  = ["c5a.2xlarge"]
      subnet_ids      = module.vpc.private_subnets
      capacity_type   = "ON_DEMAND"
      disk_size       = 30
      k8s_labels      = {
        "testground.node.role.plan" = "true"
      }

      //remote_access = true
      //ec2_ssh_key   = "sysrex"

      # Node Group scaling configuration
      max_size     = 200
      min_size     = 6
      desired_size = 6

      create_launch_template = true
      kubelet_extra_args     = "--max-pods=234 --allowed-unsafe-sysctls=net.core.somaxconn --use-max-pods=false"
      bootstrap_extra_args   = ""

      # pre_userdata can be used in both cases where you provide custom_ami_id or ami_type
      //pre_userdata = <<-EOT
      //sudo bash -c 'cat <<SYSCTL > /etc/sysctl.d/999-testground.conf
      //fs.file-max = 3178504
      //net.core.somaxconn = 131072
      //net.netfilter.nf_conntrack_max = 1048576
      //net.core.netdev_max_backlog = 524288
      //net.core.rmem_max = 16777216
      //net.core.wmem_max = 16777216
      //net.ipv4.tcp_rmem = 16384 131072 16777216
      //net.ipv4.tcp_wmem = 16384 131072 16777216
      //net.ipv4.tcp_mem = 262144 524288 1572864
      //net.ipv4.tcp_max_syn_backlog = 131072
      //net.ipv4.ip_local_port_range = 10000 65535
      //net.ipv4.tcp_tw_reuse = 1
      //net.ipv4.ip_forward = 1
      //net.ipv4.conf.all.rp_filter = 0
      //net.ipv4.neigh.default.gc_thresh2 = 4096
      //net.ipv4.neigh.default.gc_thresh3 = 32768
      //SYSCTL'
      //sudo sysctl -p /etc/sysctl.d/999-testground.conf"
      //sudo bash -c 'cat <<LIMITS > /etc/security/limits.d/999-limits.conf
      //* soft nproc 131072
      //* hard nproc 262144
      //* soft nofile 131072
      //* hard nofile 262144
      //LIMITS'
      //EOT
    }

//      iam:
// attachPolicyARNs:
// - arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryFullAccess
// - arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy
// - arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly
// - arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore
// - arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy

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
    Createdby   = "sysrex"
    Environment = "${local.environment}"
  }
}

module "eks_blueprints_kubernetes_addons" {
  source = "github.com/aws-ia/terraform-aws-eks-blueprints//modules/kubernetes-addons?ref=v4.17.0"

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
  enable_argocd                       = true


  argocd_helm_config = {
    values = [templatefile("${path.module}/argocd-values.yaml", {})]
  }
}

// https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket
resource "aws_s3_bucket" "bucket" {
  bucket = "${local.project_name}-${local.environment}"
  acl    = "private"

  versioning {
    enabled = true
  }
}
