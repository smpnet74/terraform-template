output "argocd_url" {
  description = "The URL for the Argo CD web UI."
  value       = "https://test-argocd.${var.domain_name}"
}

output "argocd_password_instructions" {
  description = "Command to retrieve the initial Argo CD admin password."
  value       = "echo \"Run this command to get the Argo CD admin password: kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d\""
}
