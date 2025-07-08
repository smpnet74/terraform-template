variable "civo_token" {}

variable "region" {
  type        = string
  default     = "FRA1"
  description = "The region to provision the cluster against"
}

variable "cluster_name_prefix" {
  description = "Prefix to append to the name of the cluster being created"
  type        = string
  default     = "tf-template-"
}

variable "cluster_node_size" {
  type        = string
  default     = "g4s.kube.medium"
  description = "The size of the nodes to provision. Run `civo size list` for all options"
}

variable "cluster_node_count" {
  description = "Number of nodes in the default pool"
  type        = number
  default     = 3
}

# Firewall Access
variable "kubernetes_api_access" {
  description = "List of Subnets allowed to access the Kube API"
  type        = list(any)
  default     = ["0.0.0.0/0"]
}

variable "cluster_web_access" {
  description = "List of Subnets allowed to access port 80 via the Load Balancer"
  type        = list(any)
  default     = ["0.0.0.0/0"]
}

variable "cluster_websecure_access" {
  description = "List of Subnets allowed to access port 443 via the Load Balancer"
  type        = list(any)
  default     = ["0.0.0.0/0"]
}

# Cloudflare
variable "cloudflare_api_token" {
  description = "Cloudflare API token for DNS management"
  type        = string
  sensitive   = true
}

variable "cloudflare_zone_id" {
  description = "Cloudflare Zone ID for the domain"
  type        = string
}

variable "cloudflare_email" {
  description = "Cloudflare account email"
  type        = string
}

variable "domain_name" {
  type        = string
  description = "The domain name to use for the application"
  default     = "timbersedgearb.com"
}

variable "github_token" {
  type        = string
  description = "The GitHub token to use for creating and managing the GitOps repository"
  sensitive   = true
}

variable "github_repo_name" {
  type        = string
  description = "The name of the repository to create for GitOps"
  default     = "k8s-app-configs"
}

variable "enable_bookinfo" {
  description = "Whether to deploy the Bookinfo sample application"
  type        = bool
  default     = true
}

# Output
