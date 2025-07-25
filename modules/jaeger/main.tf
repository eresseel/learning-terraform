resource "helm_release" "jaeger" {
  name             = "jaeger"
  repository       = "https://jaegertracing.github.io/helm-charts"
  create_namespace = true
  namespace        = "tracing"
  chart            = "jaeger"
  version          = "3.4.1"
  wait             = true

  values = [
    file("${path.module}/values.yml")
  ]
}
