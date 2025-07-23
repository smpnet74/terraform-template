
output "hubble_ui_access" {
  description = "Command to access the Hubble UI for Cilium network observability."
  value       = "cilium hubble ui"
}

# Output to verify installation
output "ambient_mesh_status_command" {
  value = module.gloo_operator.ambient_mesh_status_command
  description = "Command to check the status of the Ambient Mesh installation"
}

output "ambient_mesh_pods_command" {
  value = module.gloo_operator.ambient_mesh_pods_command
  description = "Command to check the status of the Istio pods"
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
  value       = module.kubeblocks.kubeblocks_info
}



output "civo_kubeconfig_command" {
  description = "Command to download and install the Civo Kubernetes cluster config"
  value       = "civo kubernetes config ${var.cluster_name_prefix}cluster --save"
}





