resource "helm_release" "portainer" {
  name             = "portainer"
  repository       = "https://portainer.github.io/k8s/"
  create_namespace = true
  namespace        = "portainer"
  chart            = "portainer"
  version          = "1.0.59"
  wait             = true

  values = [
    file("${path.module}/values.yml")
  ]
}
