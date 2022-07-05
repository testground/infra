variable "aws_region" {}

variable "aws_availability_zone" {}

variable "default_tags" {
  type = map
  description = "change KubernetesCluster to fit your cluster name"

  default = {
    Name              = "taas-daemon-datadir-volume"
    KubernetesCluster = "anton-kops.k8s.local"
  }
}
