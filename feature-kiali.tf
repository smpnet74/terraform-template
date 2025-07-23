# Kiali Service Mesh Observability Feature Module
module "kiali" {
  source = "./feature-kiali"
  
  # Core Configuration
  enable_prometheus_operator = var.enable_prometheus_operator
  monitoring_namespace       = var.monitoring_namespace
  domain_name               = var.domain_name
  
  # Dependencies - ensure required infrastructure exists
  depends_on = [
    module.gloo_operator.service_mesh_controller,
    helm_release.grafana,
    kubectl_manifest.default_gateway
  ]
}

