terraform {
  required_version = ">= 0.13.1"
}

provider "aws" {
  region = local.region
}

# https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/guides/getting-started#provider-setup
provider "kubernetes" {
  config_path = "~/.kube/config"
    config_context = replace("${local.project_name}", "-", ".")
}
