output "kubeflow_enabled" {
  description = "Whether Kubeflow is enabled"
  value       = var.enable_kubeflow
}

output "kubeflow_url" {
  description = "URL to access the Kubeflow dashboard"
  value       = var.enable_kubeflow ? "https://kubeflow.${var.domain_name}" : null
}

output "kubeflow_test_service_deployed" {
  description = "Whether the Kubeflow test service is deployed"
  value       = var.enable_kubeflow
}

output "kubeflow_crds_app_name" {
  description = "Name of the Kubeflow CRDs ArgoCD application"
  value       = var.enable_kubeflow ? kubectl_manifest.kubeflow_crds_app[0].name : null
}

output "kubeflow_cert_manager_app_name" {
  description = "Name of the Kubeflow cert-manager ArgoCD application"
  value       = var.enable_kubeflow ? kubectl_manifest.kubeflow_cert_manager_app[0].name : null
}

output "kubeflow_infra_app_name" {
  description = "Name of the Kubeflow infrastructure ArgoCD application"
  value       = var.enable_kubeflow ? kubectl_manifest.kubeflow_infra_app[0].name : null
}
