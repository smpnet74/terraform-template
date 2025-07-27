# AgentGateway Feature Module Variables

variable "domain_name" {
  description = "The domain name for AgentGateway UI access"
  type        = string
}

variable "enable_prometheus_operator" {
  description = "Whether Prometheus Operator is enabled for ServiceMonitor creation"
  type        = bool
  default     = false
}

variable "default_gateway_dependency" {
  description = "Dependency on the default gateway resource"
  type        = any
  default     = null
}