# Kyverno Feature Module Outputs

output "kyverno_namespace" {
  description = "Namespace where Kyverno is deployed"
  value       = var.enable_kyverno ? "kyverno" : "Kyverno is disabled"
}

output "policy_reporter_url" {
  description = "URL to access Policy Reporter UI"
  value       = var.enable_kyverno && var.enable_policy_reporter_ui ? "https://policy-reporter.${var.domain_name}" : "Policy Reporter UI is disabled"
}

output "kyverno_status_commands" {
  description = "Commands to check Kyverno status"
  value = var.enable_kyverno ? join("\n", [
    "# Check Kyverno deployment status:",
    "kubectl get pods -n kyverno",
    "kubectl get clusterpolicies",
    "kubectl get validatingwebhookconfigurations | grep kyverno",
    "kubectl get mutatingwebhookconfigurations | grep kyverno"
  ]) : "Kyverno is disabled"
}

output "policy_info" {
  description = "Information about deployed Kyverno policies"
  value = var.enable_kyverno ? join("\n", [
    "🛡️ Kyverno Policy Engine deployed with the following policies:",
    "",
    "📋 Pre-built Policies: ${var.enable_kyverno_policies ? "Enabled (baseline security policies)" : "Disabled"}",
    "📋 Custom Policies: Gateway API validation, Cilium governance, Istio preparation",
    "📋 Policy Reporter UI: ${var.enable_policy_reporter_ui ? "https://policy-reporter.${var.domain_name}" : "Disabled"}",
    "",
    "🔍 Policy Status Commands:",
    "kubectl get clusterpolicies",
    "kubectl get policyreports -A",
    "kubectl get clusterpolicyreports"
  ]) : "Kyverno is disabled"
}