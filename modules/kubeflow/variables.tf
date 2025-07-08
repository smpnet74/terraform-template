variable "enable_kubeflow" {
  description = "Whether to deploy Kubeflow"
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

variable "github_repository" {
  description = "The GitHub repository resource to depend on"
  type        = any
}

variable "domain_name" {
  description = "Domain name for application ingress"
  type        = string
}

variable "argocd_helm_release" {
  description = "The ArgoCD Helm release to depend on"
  type        = any
}

variable "service_mesh_controller" {
  description = "The service mesh controller to depend on"
  type        = any
}

variable "wait_for_service_mesh_controller" {
  description = "The time sleep resource to wait for service mesh controller"
  type        = any
}
