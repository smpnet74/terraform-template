# Kyverno Policy Engine Feature Variables

variable "enable_kyverno" {
  description = "Enable Kyverno policy engine deployment"
  type        = bool
}

variable "enable_kyverno_policies" {
  description = "Enable pre-built Kyverno security policies"
  type        = bool
}

variable "kyverno_chart_version" {
  description = "Version of the Kyverno Helm chart"
  type        = string
}

variable "kyverno_policies_chart_version" {
  description = "Version of the Kyverno policies Helm chart"
  type        = string
}

variable "kyverno_policy_exclusions" {
  description = "List of namespaces to exclude from Kyverno policies"
  type        = list(string)
}

variable "domain_name" {
  description = "Domain name for cluster resources"
  type        = string
}

variable "enable_policy_reporter_ui" {
  description = "Enable Policy Reporter UI deployment"
  type        = bool
}

variable "policy_reporter_chart_version" {
  description = "Version of the Policy Reporter Helm chart"
  type        = string
}

variable "enable_prometheus_operator" {
  description = "Enable Prometheus operator integration"
  type        = bool
}

# Note: Module dependencies are handled at the module call level 
# via depends_on in the calling module configuration