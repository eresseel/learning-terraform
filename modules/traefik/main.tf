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

data "external" "crt" {
  program = ["bash", "-c", <<-EOT
    jq -n --rawfile key "${path.module}/certs/fullchain.pem" '{"base64_value":$key}'
  EOT
  ]
}

data "external" "key" {
  program = ["bash", "-c", <<-EOT
    jq -n --rawfile key "${path.module}/certs/privkey.pem" '{"base64_value":$key}'
  EOT
  ]
}

resource "kubernetes_secret" "wildcard_cert" {
  metadata {
    name      = "wildcard-cert-secret"
    namespace = "traefik"
  }

  data = {
    "tls.crt" = data.external.crt.result["base64_value"]
    "tls.key" = data.external.key.result["base64_value"]
  }

  type = "Opaque"
}
