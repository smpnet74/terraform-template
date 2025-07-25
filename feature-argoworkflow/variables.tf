variable "enable_argo_workflows" {
  description = "Enable cluster-wide Argo Workflows and Events deployment"
  type        = bool
}

variable "argo_namespace" {
  description = "Namespace for Argo Workflows and Events control plane (workflows can run in any namespace)"
  type        = string
  default     = "argo"
}

variable "argo_workflows_chart_version" {
  description = "Version of the Argo Workflows Helm chart"
  type        = string
}

variable "argo_events_chart_version" {
  description = "Version of the Argo Events Helm chart"
  type        = string
}

variable "jetstream_version" {
  description = "Version of JetStream to use for EventBus"
  type        = string
}

variable "domain_name" {
  description = "Domain name for Argo Workflows UI"
  type        = string
}
