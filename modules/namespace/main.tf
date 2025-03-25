resource "kubernetes_namespace" "minikube" {
  for_each = var.namespace_names

  metadata {
    name = "${each.value}"
  }
}
