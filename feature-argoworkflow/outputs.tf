output "argo_workflows_url" {
  description = "URL for the Argo Workflows UI"
  value       = var.enable_argo_workflows ? "https://argo-workflows.${var.domain_name}" : null
}

output "argo_namespace" {
  description = "Namespace where Argo Workflows and Events are deployed"
  value       = var.enable_argo_workflows ? var.argo_namespace : null
}
