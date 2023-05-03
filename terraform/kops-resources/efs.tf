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
resource "aws_iam_policy" "efs_csi_driver" {
  name        = "efs-csi-policy"
  path        = "/"
  description = "Policy for the EFS CSI driver"

//  policy = data.aws_iam_policy_document.efs_csi_driver.json
    policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "elasticfilesystem:DescribeAccessPoints",
        "elasticfilesystem:DescribeFileSystems",
        "elasticfilesystem:DescribeMountTargets",
        "ec2:DescribeAvailabilityZones"
      ],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "elasticfilesystem:CreateAccessPoint"
      ],
      "Resource": "*",
      "Condition": {
        "StringLike": {
          "aws:RequestTag/efs.csi.aws.com/cluster": "true"
        }
      }
    },
    {
      "Effect": "Allow",
      "Action": [
        "elasticfilesystem:TagResource"
      ],
      "Resource": "*",
      "Condition": {
        "StringLike": {
          "aws:ResourceTag/efs.csi.aws.com/cluster": "true"
        }
      }
    },
    {
      "Effect": "Allow",
      "Action": "elasticfilesystem:DeleteAccessPoint",
      "Resource": "*",
      "Condition": {
        "StringEquals": {
          "aws:ResourceTag/efs.csi.aws.com/cluster": "true"
        }
      }
    }
  ]
}
EOF
}

data "aws_iam_policy_document" "instance_assume_role_policy" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["*"]
    }
  }
}
resource "aws_iam_role" "example" {
  name                = "efs-csi-role"
  assume_role_policy = data.aws_iam_policy_document.instance_assume_role_policy.json
  managed_policy_arns = [aws_iam_policy.efs_csi_driver.arn]
}
