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

output "bookinfo_url" {
  value = "https://bookinfo.${var.domain_name}"
  description = "URL to access the Bookinfo sample application through KGateway"
}

output "bookinfo_kiali_view" {
  value = "Open Kiali and navigate to 'Graph' view, then select 'bookinfo' namespace to visualize the service mesh"
  description = "Instructions for viewing the Bookinfo application in Kiali"
}

# KubeBlocks information
output "kubeblocks_info" {
  description = "Information about the KubeBlocks installation and available addons"
  value = <<-EOT
    KubeBlocks has been installed in the kb-system namespace.
    
    To access KubeBlocks:
    kubectl get pods -n kb-system
    
    PostgreSQL addon has been installed. You can create instances with:
    kubectl apply -f scripts/test-postgres.yaml
    kubectl apply -f scripts/test-postgres-ha.yaml
    kubectl apply -f scripts/test-redis.yaml
    kubectl apply -f scripts/test-mongodb.yaml
  EOT
}
