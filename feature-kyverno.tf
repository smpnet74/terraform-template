# Kyverno Policy Engine Feature Module
module "kyverno" {
  source = "./feature-kyverno"
  
  # Core Configuration
  enable_kyverno                   = var.enable_kyverno
  enable_kyverno_policies          = var.enable_kyverno_policies
  kyverno_chart_version           = var.kyverno_chart_version
  kyverno_policies_chart_version  = var.kyverno_policies_chart_version
  kyverno_policy_exclusions       = var.kyverno_policy_exclusions
  
  # Policy Reporter UI Configuration
  enable_policy_reporter_ui       = var.enable_policy_reporter_ui
  policy_reporter_chart_version   = var.policy_reporter_chart_version
  
  # Infrastructure
  domain_name                     = var.domain_name
  enable_prometheus_operator      = var.enable_prometheus_operator
  
  # Dependencies - ensure required infrastructure exists
  depends_on = [
    time_sleep.wait_for_cluster,
    null_resource.cilium_upgrade,  # Ensure Cilium is ready before policies
    time_sleep.wait_for_prometheus_operator,  # Wait for Prometheus Operator to be fully ready
    kubectl_manifest.default_gateway,
    kubernetes_secret.cloudflare_origin_cert
  ]
}

# Outputs from Kyverno feature
output "kyverno_namespace" {
  description = "Namespace where Kyverno is deployed"
  value       = module.kyverno.kyverno_namespace
}

output "policy_reporter_url" {
  description = "URL to access Policy Reporter UI"
  value       = module.kyverno.policy_reporter_url
}

output "kyverno_status_commands" {
  description = "Commands to check Kyverno status"
  value       = module.kyverno.kyverno_status_commands
}

output "kyverno_policy_info" {
  description = "Information about deployed Kyverno policies"
  value       = module.kyverno.policy_info
}