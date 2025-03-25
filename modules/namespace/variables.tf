variable "namespace_names" {
  type    = set(string)
  default = ["metallb-system", "portainer", "traefik", "monitoring", "rook-ceph", "ci-cd"]
}
