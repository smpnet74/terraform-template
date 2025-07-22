# Prometheus Operator Module
module "prometheus_operator" {
  source = "./operator-prometheus"
  
  # Core Configuration
  enable_prometheus_operator         = var.enable_prometheus_operator
  prometheus_operator_chart_version  = var.prometheus_operator_chart_version
  monitoring_namespace               = var.monitoring_namespace
  
  # Dependencies - ensure required infrastructure exists
  depends_on = [
    time_sleep.wait_for_cluster
  ]
}

# Outputs from Prometheus Operator module
output "prometheus_operator_info" {
  description = "Information about the Prometheus Operator monitoring stack"
  value       = module.prometheus_operator.prometheus_operator_info
}

output "monitoring_endpoints" {
  description = "Local port-forward commands for monitoring stack components"
  value       = module.prometheus_operator.monitoring_endpoints
}