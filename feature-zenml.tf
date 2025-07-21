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
    helm_release.kubeblocks,
    kubectl_manifest.default_gateway
  ]
}

# Outputs from ZenML feature
output "zenml_url" {
  description = "ZenML UI URL"
  value       = module.zenml.zenml_url
}

output "zenml_admin_token" {
  description = "ZenML admin token"
  value       = module.zenml.zenml_admin_token
  sensitive   = true
}

output "zenml_postgres_host" {
  description = "ZenML PostgreSQL host"
  value       = module.zenml.zenml_postgres_host
}

output "zenml_artifact_bucket_name" {
  description = "ZenML artifact storage bucket name"
  value       = module.zenml.zenml_artifact_bucket_name
}

output "zenml_artifact_bucket_url" {
  description = "ZenML artifact storage bucket URL"  
  value       = module.zenml.zenml_artifact_bucket_url
}