# Prometheus Operator Module Outputs

output "monitoring_namespace" {
  description = "Namespace where Prometheus Operator is deployed"
  value       = var.enable_prometheus_operator ? var.monitoring_namespace : null
}

output "prometheus_operator_info" {
  description = "Information about the Prometheus Operator monitoring stack"
  value = var.enable_prometheus_operator ? join("\n", [
    "🔍 Prometheus Operator v${var.prometheus_operator_chart_version} deployed in ${var.monitoring_namespace} namespace:",
    "",
    "📊 Components:",
    "• Prometheus Server: kubectl port-forward svc/kube-prometheus-stack-prometheus -n ${var.monitoring_namespace} 9090:9090",
    "• Alertmanager: kubectl port-forward svc/kube-prometheus-stack-alertmanager -n ${var.monitoring_namespace} 9093:9093", 
    "• Node Exporter: Deployed on all nodes for system metrics",
    "• kube-state-metrics: Kubernetes resource metrics collection",
    "",
    "🎯 Service Discovery:",
    "• ServiceMonitor CRDs: Automatic service discovery for monitoring",
    "• PrometheusRule CRDs: Declarative alerting rules",
    "• Cross-namespace monitoring enabled",
    "",
    "🔗 Integrations:",
    "• Kiali: Connected to Prometheus for service mesh metrics",
    "• Grafana: Using Prometheus as primary datasource",
    "• Policy Reporter: ServiceMonitor enabled for policy metrics",
    "",
    "📋 Management Commands:",
    "• View ServiceMonitors: kubectl get servicemonitors -A",
    "• View PrometheusRules: kubectl get prometheusrules -A",
    "• Check Prometheus config: kubectl get prometheus -n ${var.monitoring_namespace} -o yaml"
  ]) : "Prometheus Operator is disabled"
}

output "monitoring_endpoints" {
  description = "Local port-forward commands for monitoring stack components"
  value = var.enable_prometheus_operator ? join("\n", [
    "# Access monitoring components locally:",
    "kubectl port-forward svc/kube-prometheus-stack-prometheus -n ${var.monitoring_namespace} 9090:9090",
    "kubectl port-forward svc/kube-prometheus-stack-alertmanager -n ${var.monitoring_namespace} 9093:9093"
  ]) : "Prometheus Operator is disabled"
}