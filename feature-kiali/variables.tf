# Kiali Service Mesh Observability Feature Variables

variable "enable_prometheus_operator" {
  description = "Enable Prometheus Operator for monitoring integration"
  type        = bool
}

variable "monitoring_namespace" {
  description = "Namespace where Prometheus Operator is deployed"
  type        = string
}

variable "domain_name" {
  description = "Domain name for external access configuration"
  type        = string
}

# Note: Module dependencies are handled at the module call level 
# via depends_on in the calling module configuration