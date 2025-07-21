# ZenML Feature Variables
variable "enable_zenml" {
  description = "Enable ZenML deployment"
  type        = bool
}

variable "zenml_namespace" {
  description = "Namespace for ZenML resources"
  type        = string
}

variable "zenml_server_version" {
  description = "ZenML server version"
  type        = string
}

variable "zenml_artifact_bucket" {
  description = "Name of the Civo Object Store bucket for ZenML artifacts"
  type        = string
}

variable "zenml_artifact_bucket_size" {
  description = "Maximum size of the ZenML artifact bucket in GB"
  type        = number
}

variable "domain_name" {
  description = "Domain name for ZenML UI"
  type        = string
}

variable "region" {
  description = "Civo region"
  type        = string
}

variable "monitoring_namespace" {
  description = "Namespace for monitoring resources"
  type        = string
}

variable "enable_prometheus_operator" {
  description = "Enable Prometheus operator integration"
  type        = bool
}

variable "enable_kyverno" {
  description = "Enable Kyverno policy integration"
  type        = bool
}