# Gloo Operator Variables

variable "istio_version" {
  description = "Version of Istio to install via Gloo Operator"
  type        = string
  default     = "1.26.2"
}