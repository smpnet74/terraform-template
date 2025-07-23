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

# User-friendly formatted outputs
output "zenml_ui_url" {
  description = "URL to access the ZenML Server web UI."
  value       = var.enable_zenml ? "https://zenml.${var.domain_name}" : "ZenML is disabled."
}

output "zenml_connect_command" {
  description = "Command to connect the ZenML CLI to the deployed server."
  value       = var.enable_zenml ? "zenml connect --url https://zenml.${var.domain_name} --token ${random_password.zenml_admin_token[0].result}" : "ZenML is disabled."
  sensitive   = true
}

output "zenml_bucket_info" {
  description = "Information about the created S3-compatible bucket for ZenML artifacts."
  value = var.enable_zenml ? join("\n", [
    "📦 ZenML Artifact Storage Information:",
    "",
    "Bucket Name: ${civo_object_store.zenml_artifacts[0].name}",
    "Bucket Size: ${var.zenml_artifact_bucket_size}GB",
    "Bucket URL: ${civo_object_store.zenml_artifacts[0].bucket_url}",
    "Region: ${var.region}",
    "Endpoint URL: https://object-store.${var.region}.civo.com",
    "",
    "🔑 To get S3 credentials for ZenML configuration:",
    "",
    "1. Go to Civo Dashboard: https://dashboard.civo.com",
    "2. Navigate: Object Storage → ${civo_object_store.zenml_artifacts[0].name}",
    "3. Click on the 'Credentials' tab",
    "4. Click 'Create New Credential' (name it whatever you want)",
    "5. Copy the Access Key ID and Secret Access Key",
    "",
    "💡 You'll need these credentials when configuring ZenML artifact store",
    "   either through the ZenML UI or CLI commands shown in 'zenml_stack_setup_commands'."
  ]) : "ZenML is disabled."
}

output "zenml_stack_setup_commands" {
  description = "CLI commands to configure ZenML stack after getting S3 credentials."
  value = var.enable_zenml ? join("\n", [
    "🚀 ZenML Stack Configuration Commands:",
    "",
    "# 1. Connect to your ZenML server",
    "zenml connect --url https://zenml.${var.domain_name} --token <admin-token>",
    "",
    "# 2. Register the S3 artifact store (after getting credentials from Civo UI)",
    "zenml artifact-store register ${civo_object_store.zenml_artifacts[0].name} --flavor=s3 \\",
    "  --path=s3://${civo_object_store.zenml_artifacts[0].name} \\",
    "  --aws_access_key_id=<your-access-key-id> \\",
    "  --aws_secret_access_key=<your-secret-access-key> \\",
    "  --client_kwargs='{\"endpoint_url\": \"https://object-store.${var.region}.civo.com\"}'",
    "",
    "# 3. Register a new stack with the artifact store",
    "zenml stack register production-stack -o default -a ${civo_object_store.zenml_artifacts[0].name}",
    "",
    "# 4. Set the new stack as active",
    "zenml stack set production-stack",
    "",
    "# 5. Verify your setup",
    "zenml stack describe"
  ]) : "ZenML is disabled."
}