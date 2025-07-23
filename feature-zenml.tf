# ZenML Feature Module
module "zenml" {
  source = "./feature-zenml"
  
  # Core Configuration
  enable_zenml                = var.enable_zenml
  zenml_namespace            = var.zenml_namespace
  zenml_server_version       = var.zenml_server_version
  zenml_artifact_bucket      = var.zenml_artifact_bucket
  zenml_artifact_bucket_size = var.zenml_artifact_bucket_size
  
  # Infrastructure
  domain_name               = var.domain_name
  region                    = var.region
  
  # Integration
  monitoring_namespace       = var.monitoring_namespace
  enable_prometheus_operator = var.enable_prometheus_operator
  enable_kyverno            = var.enable_kyverno
  
  # Dependencies - ensure required infrastructure exists
  depends_on = [
    module.kubeblocks,
    kubectl_manifest.default_gateway
  ]
}

