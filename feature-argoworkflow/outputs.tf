output "argo_workflows_url" {
  description = "URL for the Argo Workflows UI (cluster-wide visibility)"
  value       = var.enable_argo_workflows ? "https://argo-workflows.${var.domain_name}" : null
}

output "argo_namespace" {
  description = "Control plane namespace for Argo Workflows and Events (workflows can run in any namespace)"
  value       = var.enable_argo_workflows ? var.argo_namespace : null
}

output "cluster_workflow_templates" {
  description = "Available ClusterWorkflowTemplates for cluster-wide use"
  value = var.enable_argo_workflows ? [
    "container-build-deploy",
    "database-migration", 
    "run-tests",
    "security-scan",
    "backup-restore"
  ] : []
}

output "operational_commands" {
  description = "Key operational commands for cluster-wide Argo Workflows"
  value = var.enable_argo_workflows ? {
    list_workflows_all_namespaces = "kubectl get workflows -A"
    list_cluster_templates        = "kubectl get clusterworkflowtemplates"
    check_eventbus_status        = "kubectl get eventbus -n ${var.argo_namespace}"
    controller_logs              = "kubectl logs -f deployment/workflow-controller -n ${var.argo_namespace}"
    server_logs                  = "kubectl logs -f deployment/argo-server -n ${var.argo_namespace}"
    verify_cluster_permissions   = "kubectl auth can-i create workflows --as=system:serviceaccount:${var.argo_namespace}:argo-workflow-controller -A"
  } : {}
}
