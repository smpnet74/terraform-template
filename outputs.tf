
output "hubble_ui_access" {
  description = "Command to access the Hubble UI for Cilium network observability."
  value       = "cilium hubble ui"
}

# Output to verify installation
output "ambient_mesh_status_command" {
  value = "kubectl describe servicemeshcontroller managed-istio"
  description = "Command to check the status of the Ambient Mesh installation"
}

output "ambient_mesh_pods_command" {
  value = "kubectl get pods -n istio-system"
  description = "Command to check the status of the Istio pods"
}

output "kiali_access" {
  value = "kubectl port-forward svc/kiali -n istio-system 20001:20001"
  description = "Command to access the Kiali dashboard (then open http://localhost:20001 in your browser)"
}

output "kiali_url" {
  value = "https://kiali.${var.domain_name}"
  description = "URL to access Kiali through the Gateway API"
}

output "grafana_url" {
  value = "https://grafana.${var.domain_name}"
  description = "URL to access Grafana dashboards through the Gateway API"
}

output "grafana_credentials" {
  value = "Username: admin, Password: admin"
  description = "Default credentials for Grafana (change these in production)"
}




# KubeBlocks information
output "kubeblocks_info" {
  description = "Information about the KubeBlocks installation and available addons"
  value = join("\n", [
    "KubeBlocks has been installed in the kb-system namespace.",
    "",
    "kubectl apply -f scripts/test-postgres.yaml",
    "kubectl apply -f scripts/test-postgres-ha.yaml", 
    "kubectl apply -f scripts/test-redis.yaml",
    "kubectl apply -f scripts/test-mongodb.yaml"
  ])
}



output "civo_kubeconfig_command" {
  description = "Command to download and install the Civo Kubernetes cluster config"
  value       = "civo kubernetes config ${var.cluster_name_prefix}cluster --save"
}


# ZenML MLOps Platform
output "zenml_ui_url" {
  description = "URL to access the ZenML Server web UI."
  value       = module.zenml.zenml_url != null ? module.zenml.zenml_url : "ZenML is disabled."
}

output "zenml_connect_command" {
  description = "Command to connect the ZenML CLI to the deployed server."
  value       = var.enable_zenml ? "zenml connect --url ${module.zenml.zenml_url} --token ${module.zenml.zenml_admin_token}" : "ZenML is disabled."
  sensitive   = true
}

output "zenml_bucket_info" {
  description = "Information about the created S3-compatible bucket for ZenML artifacts."
  value = var.enable_zenml ? join("\n", [
    "📦 ZenML Artifact Storage Information:",
    "",
    "Bucket Name: ${module.zenml.zenml_artifact_bucket_name}",
    "Bucket Size: ${var.zenml_artifact_bucket_size}GB",
    "Bucket URL: ${module.zenml.zenml_artifact_bucket_url}",
    "Region: ${var.region}",
    "Endpoint URL: https://object-store.${var.region}.civo.com",
    "",
    "🔑 To get S3 credentials for ZenML configuration:",
    "",
    "1. Go to Civo Dashboard: https://dashboard.civo.com",
    "2. Navigate: Object Storage → ${module.zenml.zenml_artifact_bucket_name}",
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
    "zenml connect --url ${module.zenml.zenml_url} --token <admin-token>",
    "",
    "# 2. Register the S3 artifact store (after getting credentials from Civo UI)",
    "zenml artifact-store register ${module.zenml.zenml_artifact_bucket_name} --flavor=s3 \\",
    "  --path=s3://${module.zenml.zenml_artifact_bucket_name} \\",
    "  --aws_access_key_id=<your-access-key-id> \\",
    "  --aws_secret_access_key=<your-secret-access-key> \\",
    "  --client_kwargs='{\"endpoint_url\": \"https://object-store.${var.region}.civo.com\"}'",
    "",
    "# 3. Register a new stack with the artifact store",
    "zenml stack register production-stack -o default -a ${module.zenml.zenml_artifact_bucket_name}",
    "",
    "# 4. Set the new stack as active",
    "zenml stack set production-stack",
    "",
    "# 5. Verify your setup",
    "zenml stack describe"
  ]) : "ZenML is disabled."
}



