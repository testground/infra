terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.0"
    }
  }

  required_version = ">= 0.14"
}

# EBS for Testground daemon datadir
resource "aws_ebs_volume" "testground-daemon-datadir" {
  availability_zone = var.aws_availability_zone
  size = 10
  type = "gp2"

  tags = "${merge(var.default_tags)}"
}
