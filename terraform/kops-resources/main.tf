//################################################################################
//# Locals
//################################################################################
locals {
  region       = "eu-west-1"
  //project_name = "testground-devops-k8s-local"
  project_name = "tgdevops-k8s-local"

  azs                         = ["${local.region}a", "${local.region}b"]
  vpc_id                      = data.aws_vpc.selected.id
  vpc_cidr                    = "${split(".", data.aws_vpc.selected.cidr_block)[0]}.${split(".", data.aws_vpc.selected.cidr_block)[1]}"
  private_subnets             = [for i in data.aws_subnet_ids.private_subnets.ids : i]
  private_subnets_cidr_blocks = [for i in data.aws_subnet.aws_subnet_ids : i.cidr_block]

  ebs_types = ["gp2", "gp3"]
}

data "aws_vpc" "selected" {
  tags = {
    Name = replace("${local.project_name}", "-", ".")
  }
}

data "aws_subnet_ids" "private_subnets" {
  vpc_id = data.aws_vpc.selected.id
  tags = {
    KubernetesCluster = replace("${local.project_name}", "-", ".")
  }
}

data "aws_subnet" "aws_subnet_ids" {
  for_each = toset(data.aws_subnet_ids.private_subnets.ids)
  id       = each.value
}
