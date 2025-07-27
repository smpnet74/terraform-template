variable "civo_token" {}

variable "github_token" {
  description = "GitHub personal access token for repository management"
  type        = string
  sensitive   = true
}

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



variable "enable_argo_workflows" {
  description = "Whether to deploy Argo Workflows for in-cluster builds"
  type        = bool
  default     = false
}

variable "argo_workflows_chart_version" {
  description = "Version of the Argo Workflows Helm chart"
  type        = string
  default     = "0.45.19"  # Argo Workflows 3.6.10
}

variable "argo_events_chart_version" {
  description = "Version of the Argo Events Helm chart"
  type        = string
  default     = "2.4.15"   # Compatible with Argo Workflows 3.6.10
}

variable "jetstream_version" {
  description = "Version of JetStream for Argo Events EventBus"
  type        = string
  default     = "2.10.10"  # Uses config reloader 0.14.0 (working version)
}

variable "metrics_server_chart_version" {
  description = "Version of the Metrics Server Helm chart"
  type        = string
  default     = "3.12.1"  # Latest stable version
}

# Kyverno Configuration
variable "enable_kyverno" {
  description = "Whether to deploy Kyverno policy engine"
  type        = bool
  default     = true
}

variable "kyverno_chart_version" {
  description = "Version of the Kyverno Helm chart"
  type        = string
  default     = "3.4.4"  # Kyverno v1.14.4
}

variable "kyverno_policies_chart_version" {
  description = "Version of the Kyverno Policies Helm chart"
  type        = string
  default     = "3.4.4"  # Compatible with Kyverno v1.14.4
}

variable "enable_kyverno_policies" {
  description = "Whether to deploy pre-built Kyverno policies"
  type        = bool
  default     = true
}

variable "kyverno_policy_exclusions" {
  description = "Namespaces to exclude from Kyverno policies"
  type        = list(string)
  default     = ["kube-system", "kyverno", "kgateway-system", "local-path-storage"]
}

variable "enable_policy_reporter_ui" {
  description = "Whether to deploy Policy Reporter UI for web-based policy management"
  type        = bool
  default     = true
}

variable "policy_reporter_chart_version" {
  description = "Version of the Policy Reporter Helm chart"
  type        = string
  default     = "3.3.1"   # Latest stable version with UI support
}

# Prometheus Operator Configuration
variable "enable_prometheus_operator" {
  description = "Whether to deploy Prometheus Operator for cluster monitoring"
  type        = bool
  default     = true
}

variable "prometheus_operator_chart_version" {
  description = "Version of the kube-prometheus-stack Helm chart"
  type        = string
  default     = "61.9.0"  # Latest stable version
}

variable "monitoring_namespace" {
  description = "Namespace for monitoring components (Prometheus, Grafana, Alertmanager)"
  type        = string
  default     = "monitoring"
}

# ZenML MLOps Platform
variable "enable_zenml" {
  description = "Whether to deploy the ZenML MLOps platform"
  type        = bool
  default     = false
}

variable "zenml_chart_version" {
  description = "Helm chart version for ZenML Server"
  type        = string
  default     = "0.84.0" # Latest version as of July 2025
}

variable "zenml_server_version" {
  description = "Version of the ZenML server Docker image"
  type        = string
  default     = "0.84.0"
}

variable "zenml_postgres_version" {
  description = "Version of the KubeBlocks PostgreSQL instance"
  type        = string
  default     = "apecloud-postgresql-15.3.0"
}

variable "zenml_namespace" {
  description = "Namespace for ZenML components"
  type        = string
  default     = "zenml-system"
}

variable "zenml_artifact_bucket" {
  description = "Name of the Civo Object Store bucket for ZenML artifacts"
  type        = string
  default     = "zenml-artifacts"
}

variable "zenml_artifact_bucket_size" {
  description = "Size of the Civo Object Store bucket for ZenML artifacts in GB (must be multiple of 500)"
  type        = number
  default     = 500
}

# KubeBlocks Operator Configuration
variable "kubeblocks_version" {
  description = "Version of KubeBlocks to install"
  type        = string
  default     = "1.0.0"
}

variable "enable_neo4j_addon" {
  description = "Enable Neo4j addon for KubeBlocks"
  type        = bool
  default     = false
}

# Gloo Operator Configuration  
variable "istio_version" {
  description = "Version of Istio to install via Gloo Operator"
  type        = string
  default     = "1.26.2"
}

# AgentGateway Configuration
variable "enable_agentgateway" {
  description = "Whether to deploy AgentGateway for MCP and A2A communication"
  type        = bool
  default     = false
}




