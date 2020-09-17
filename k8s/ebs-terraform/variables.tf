variable "aws_region" {}

variable "aws_availability_zone" {}

variable "default_tags" {
  type = "map"

  default = {
    Name              = "taas-daemon-datadir-volume"
    KubernetesCluster = "anton-kops.k8s.local"
  }
}
