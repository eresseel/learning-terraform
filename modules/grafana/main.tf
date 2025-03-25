resource "helm_release" "grafana" {
  name             = "grafana"
  repository       = "https://grafana.github.io/helm-charts"
  namespace        = "monitoring"
  create_namespace = true
  chart            = "grafana"
  version          = "8.8.2"
  wait             = true

  values = [
    file("${path.module}/values.yml")
  ]
}