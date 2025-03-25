resource "helm_release" "gitlab" {
  name       = "gitlab"
  repository = "http://charts.gitlab.io/"
  namespace  = "ci-cd"
  create_namespace = true
  chart      = "gitlab"
  version    = "8.8.2"
  wait       = true
  timeout    = 1800

  values = [
    file("${path.module}/values.yml")
  ]
}
