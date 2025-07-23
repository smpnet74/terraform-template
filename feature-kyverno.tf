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
    module.prometheus_operator,  # Wait for Prometheus Operator to be fully ready
    kubectl_manifest.default_gateway,
    kubernetes_secret.cloudflare_origin_cert
  ]
}

