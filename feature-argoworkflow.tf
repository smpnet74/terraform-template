# Argo Workflows Feature Module
module "argoworkflow" {
  source = "./feature-argoworkflow"
  
  # Core Configuration
  enable_argo_workflows      = var.enable_argo_workflows
  argo_namespace             = "argo"
  argo_workflows_chart_version = var.argo_workflows_chart_version
  argo_events_chart_version  = var.argo_events_chart_version
  jetstream_version          = var.jetstream_version
  
  # Infrastructure
  domain_name                = var.domain_name
  
  # Dependencies - ensure required infrastructure exists
  depends_on = [
    time_sleep.wait_for_cluster,
    kubectl_manifest.default_gateway
  ]
}

