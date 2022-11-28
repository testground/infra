output "volume_id" {
  value       = aws_ebs_volume.testground-daemon-datadir.id
}

output "availability_zone" {
  value       = var.aws_availability_zone
}

