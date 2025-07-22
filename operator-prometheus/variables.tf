# Prometheus Operator Module Variables

variable "enable_prometheus_operator" {
  description = "Enable Prometheus Operator deployment"
  type        = bool
}

variable "prometheus_operator_chart_version" {
  description = "Version of the kube-prometheus-stack Helm chart"
  type        = string
}

variable "monitoring_namespace" {
  description = "Namespace for monitoring stack deployment"
  type        = string
}

# Note: Module dependencies are handled at the module call level 
# via depends_on in the calling module configuration