provider "aws" {
  region  = var.aws_region
  version = "~> 2.50"
}

# EFS for Testground outputs
resource "aws_efs_file_system" "default" {
  count           = 1
}

resource "aws_efs_mount_target" "target_subnet_zone_a" {
  count           = 1
  file_system_id  = join("", aws_efs_file_system.default.*.id)
  subnet_id       = var.fs_subnet_id_zone_a
  security_groups = [var.fs_sg_id]
}

resource "aws_efs_mount_target" "target_subnet_zone_b" {
  count           = 1
  file_system_id  = join("", aws_efs_file_system.default.*.id)
  subnet_id       = var.fs_subnet_id_zone_b
  security_groups = [var.fs_sg_id]
}
