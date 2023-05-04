terraform {
  backend "s3" {
    bucket = "testground-terraform-state"
    key    = "jose.k8s.local-tf-state-devops-tg"
    region = "eu-west-1"
  }
}
