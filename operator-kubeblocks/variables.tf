# KubeBlocks Operator Variables

variable "kubeblocks_version" {
  description = "Version of KubeBlocks to install"
  type        = string
  default     = "1.0.0"
}

variable "kubeconfig_path" {
  description = "Path to kubeconfig file for cluster access"
  type        = string
}