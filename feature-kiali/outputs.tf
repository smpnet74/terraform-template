# Kiali Service Mesh Observability Feature Outputs

output "kiali_access_command" {
  description = "Command to access the Kiali dashboard locally"
  value       = "kubectl port-forward svc/kiali -n istio-system 20001:20001"
}

output "kiali_url" {
  description = "URL to access Kiali through the Gateway API"
  value       = "https://kiali.${var.domain_name}"
}

output "prometheus_info" {
  description = "Information about Prometheus deployment for Kiali"
  value = var.enable_prometheus_operator ? "Using Prometheus Operator in ${var.monitoring_namespace} namespace" : "Using basic Prometheus server in istio-system namespace"
}