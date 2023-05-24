resource "kubernetes_storage_class_v1" "ebs" {
  for_each = toset(local.ebs_types)

  metadata {
    name = "${each.key}-retain"
  }

  storage_provisioner = "kubernetes.io/aws-ebs"
  parameters = {
    type = each.key
  }

  reclaim_policy = "Retain"

  mount_options = [
    "debug"
  ]

  volume_binding_mode = "Immediate"
}
