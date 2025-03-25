resource "helm_release" "metrics-server" {
  name             = "metrics-server"
  repository       = "https://kubernetes-sigs.github.io/metrics-server/"
  create_namespace = true
  namespace        = "kube-system"
  chart            = "metrics-server"
  version          = "3.12.2"
  wait             = true

  values = [
    file("${path.module}/values.yml")
  ]
}
