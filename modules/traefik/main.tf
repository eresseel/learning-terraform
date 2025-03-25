resource "helm_release" "traefik" {
  name             = "traefik"
  repository       = "https://traefik.github.io/charts"
  create_namespace = true
  namespace        = "traefik"
  chart            = "traefik"
  version          = "33.2.1"
  wait             = true

  values = [
    file("${path.module}/values.yml")
  ]
}
