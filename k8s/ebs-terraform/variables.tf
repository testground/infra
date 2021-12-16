variable "aws_region" {}

variable "aws_availability_zone" {}

variable "default_tags" {
  type = map

  # this should be dynamic
  default = {
    Name              = "taas-daemon-datadir-volume"
    KubernetesCluster = "testground.k8s.local"
  }
}
