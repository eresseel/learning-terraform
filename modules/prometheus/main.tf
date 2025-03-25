resource "helm_release" "prometheus" {
  name             = "prometheus"
  repository       = "https://prometheus-community.github.io/helm-charts"
  namespace        = "monitoring"
  create_namespace = true
  chart            = "prometheus"
  version          = "26.1.0"
  wait             = true

  values = [
    file("${path.module}/values.yml")
  ]
}
