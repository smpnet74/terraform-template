
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


output "argo_workflows_url" {
  description = "The URL for the Argo Workflows web UI."
  value       = var.enable_argo_workflows ? "https://argo-workflows.${var.domain_name}" : "disabled"
}

# Kyverno information
output "kyverno_ui_info" {
  description = "Information about Kyverno web interface availability."
  value       = var.enable_kyverno ? "Kyverno CLI-based management (no web UI deployed). To add Policy Reporter UI, see httproute_kyverno.tf" : "Kyverno is disabled"
}

output "kyverno_status_commands" {
  description = "Commands to check Kyverno status and policies"
  value = var.enable_kyverno ? join("\n", [
    "Check Kyverno pods:        kubectl get pods -n kyverno",
    "View cluster policies:     kubectl get clusterpolicies", 
    "View policy reports:       kubectl get clusterpolicyreports",
    "View background reports:   kubectl get backgroundscanreports"
  ]) : "Kyverno is disabled"
}

output "kyverno_policy_info" {
  description = "Information about deployed Kyverno policies"
  value = var.enable_kyverno ? join("\n", [
    "Kyverno Policy Engine v1.14.4 has been deployed with:",
    "",
    "• Pre-built policies: ${var.enable_kyverno_policies ? "Enabled (Pod Security Standards baseline)" : "Disabled"}",
    "• Custom policies: Gateway API governance, Cilium Network Policy governance", 
    "• Ambient Mesh preparation: Automatic namespace labeling for Istio",
    "• Certificate validation: Cloudflare Origin Certificate standards",
    "• Resource requirements: CPU and memory requests enforcement",
    "",
    "Excluded namespaces: ${join(", ", var.kyverno_policy_exclusions)}"
  ]) : "Kyverno is disabled"
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
