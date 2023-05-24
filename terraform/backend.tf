terraform {
  backend "s3" {
    bucket = "testground-terraform-state"
    key    = "devops-2-tg"
    region = "eu-west-1"
  }
}
