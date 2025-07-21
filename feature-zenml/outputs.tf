# ZenML Feature Outputs
output "zenml_url" {
  description = "ZenML UI URL"
  value       = var.enable_zenml ? "https://zenml.${var.domain_name}" : null
}

output "zenml_admin_token" {
  description = "ZenML admin token"
  value       = var.enable_zenml ? random_password.zenml_admin_token[0].result : null
  sensitive   = true
}

output "zenml_postgres_host" {
  description = "ZenML PostgreSQL host"
  value       = var.enable_zenml ? "zenml-postgres-postgresql.${var.zenml_namespace}.svc.cluster.local" : null
}

output "zenml_artifact_bucket_name" {
  description = "ZenML artifact storage bucket name"
  value       = var.enable_zenml ? civo_object_store.zenml_artifacts[0].name : null
}

output "zenml_artifact_bucket_url" {
  description = "ZenML artifact storage bucket URL"
  value       = var.enable_zenml ? civo_object_store.zenml_artifacts[0].bucket_url : null
}