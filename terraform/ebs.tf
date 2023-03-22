resource "kubernetes_storage_class_v1" "ebs" {
  metadata {
    name = "gp2-retain"
  }

  storage_provisioner = "kubernetes.io/aws-ebs"
  parameters = {
    type = "gp2"
  }

  reclaim_policy = "Retain"

  mount_options = [
    "debug"
  ]

  volume_binding_mode = "Immediate"

  depends_on = [
    module.eks_blueprints_kubernetes_addons
  ]
}
