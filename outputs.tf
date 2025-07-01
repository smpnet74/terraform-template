output "argocd_url" {
  description = "The URL for the Argo CD web UI."
  value       = "https://test-argocd.${var.domain_name}"
}

output "argocd_password_instructions" {
  description = "Command to retrieve the initial Argo CD admin password."
  value       = "kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d"
}

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
