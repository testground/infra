################################################################################
# VPC Outputs
################################################################################
output "vpc" {
  value = data.aws_vpc.selected.id
}

output "vpc_all" {
  value = data.aws_vpc.selected
}

output "vpc_cidr" {
  value = data.aws_vpc.selected.cidr_block
}

output "vpc_id_cidr_init" {
  value = "${split(".", data.aws_vpc.selected.cidr_block)[0]}.${split(".", data.aws_vpc.selected.cidr_block)[1]}"
}

output "private_subnets" {
  value = data.aws_subnet_ids.private_subnets
}

output "private_subnets_ids" {
  value = data.aws_subnet_ids.private_subnets.ids
}

output "subnet_cidr_blocks" {
  value = [for i in data.aws_subnet.aws_subnet_ids : i.cidr_block]
}
