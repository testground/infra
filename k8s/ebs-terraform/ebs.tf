provider "aws" {
  region  = var.aws_region
  version = "~> 2.50"
}

# EBS for Testground daemon datadir
resource "aws_ebs_volume" "testground-daemon-datadir" {
  availability_zone = var.aws_availability_zone
  size = 10
  type = "gp2"

  tags = "${merge(var.default_tags)}"
}
