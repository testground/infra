terraform {
  backend "s3" {
    bucket = "testground-terraform-state"
    key    = "testground.k8s.local"
    region = "eu-west-1"
  }
}
