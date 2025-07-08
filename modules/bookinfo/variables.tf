variable "enable_bookinfo" {
  description = "Whether to deploy the Bookinfo sample application"
  type        = bool
  default     = true
}

variable "github_repo_name" {
  description = "Name of the GitHub repository for ArgoCD applications"
  type        = string
}

variable "github_repo_url" {
  description = "URL of the GitHub repository for ArgoCD applications"
  type        = string
}

variable "domain_name" {
  description = "Domain name for the Bookinfo application URL"
  type        = string
}

variable "argocd_helm_release" {
  description = "ArgoCD Helm release to depend on"
  type        = any
}

variable "service_mesh_controller" {
  description = "Service mesh controller to depend on"
  type        = any
  default     = null
}

variable "wait_for_service_mesh_controller" {
  description = "Wait for service mesh controller to depend on"
  type        = any
  default     = null
}
