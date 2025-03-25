resource "helm_release" "metallb" {
  name             = "metallb"
  repository       = "https://metallb.github.io/metallb"
  create_namespace = true
  namespace        = "metallb-system"
  chart            = "metallb"
  version          = "0.14.9"
  wait             = true

  values = [
    file("${path.module}/values.yml")
  ]

  provisioner "local-exec" {
    when    = create
    command = "sh ${path.module}/scripts/metallb.sh apply"
  }

  provisioner "local-exec" {
    when    = destroy
    command = "sh ${path.module}/scripts/metallb.sh delete"
  }
}
