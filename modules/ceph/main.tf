resource "helm_release" "rook-ceph" {
  name             = "rook-ceph"
  repository       = "https://charts.rook.io/release"
  create_namespace = true
  namespace        = "rook-ceph"
  chart            = "rook-ceph"
  version          = "1.16.1"
  wait             = true

  values = [
    file("${path.module}/values-operator.yml")
  ]
}

resource "helm_release" "rook-ceph-cluster" {
  depends_on       = [helm_release.rook-ceph]
  name             = "rook-ceph-cluster"
  repository       = "https://charts.rook.io/release"
  create_namespace = true
  namespace        = "rook-ceph"
  chart            = "rook-ceph-cluster"
  version          = "1.16.1"
  wait             = true

  values = [
    file("${path.module}/values-cluster.yml")
  ]
}
