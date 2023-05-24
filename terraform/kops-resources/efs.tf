# EFS for Testground outputs
locals {
  name = local.project_name
  namespace = "kube-system"
  service_account_name = "efs-csi-role"
}

module "efs" {
  source  = "terraform-aws-modules/efs/aws"
  version = "~> 1.0"

  creation_token = "${local.project_name}-efs"
  name           = "${local.project_name}-efs"

  # Mount targets / security group
  mount_targets = {
    for k, v in zipmap(local.azs, local.private_subnets) : k => { subnet_id = v }
  }
  security_group_description = "${local.name} EFS security group"
  security_group_vpc_id = local.vpc_id
  security_group_rules = {
    vpc = {
      # relying on the defaults provdied for EFS/NFS (2049/TCP + ingress)
      description = "NFS ingress from VPC private subnets"
      cidr_blocks = local.private_subnets_cidr_blocks
    }
  }

  tags = {
    Name = "${local.project_name}-efs"
  }
}

resource "kubernetes_storage_class_v1" "efs" {
  metadata {
    name = "aws-efs"
  }

  storage_provisioner = "efs.csi.aws.com"

  parameters = {
    provisioningMode = "efs-ap" # Dynamic provisioning
    fileSystemId     = module.efs.id
    directoryPerms   = "700"
  }

  mount_options = [
    "iam"
  ]
}
