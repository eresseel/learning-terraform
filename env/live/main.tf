module "namespace" {
  source = "../../modules/namespace"
}

//module "ceph" {
//  depends_on = [module.namespace]
//  source = "../../modules/ceph"
//}

module "metrics" {
  source     = "../../modules/metrics"
}

module "metallb" {
  depends_on = [module.namespace]
  source     = "../../modules/metallb"
}

module "traefik" {
  depends_on = [module.namespace]
  source     = "../../modules/traefik"
}

module "portainer" {
  depends_on = [module.namespace]
  source     = "../../modules/portainer"
}

module "prometheus" {
  depends_on = [module.namespace]
  source = "../../modules/prometheus"
}

module "grafana" {
  depends_on = [module.namespace]
  source = "../../modules/grafana"
}

module "gitlab" {
  depends_on = [module.namespace]
  source = "../../modules/gitlab"
}
