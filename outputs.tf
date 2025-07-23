# =============================================================================
# INFRASTRUCTURE CORE OUTPUTS
# =============================================================================

output "a_infrastructure_core" {
  description = "Essential cluster access information"
  value = join("\n", [
    "=============================================================================",
    "INFRASTRUCTURE CORE",
    "=============================================================================",
    "",
    "Terraform Template Cluster Information:",
    "",
    "Cluster: ${var.cluster_name_prefix}cluster (${var.region})",
    "Kubeconfig: ${path.module}/kubeconfig", 
    "Download: civo kubernetes config ${var.cluster_name_prefix}cluster --save",
    "Network: Cilium CNI with Hubble observability",
    "Hubble UI: cilium hubble ui"
  ])
}

output "service_mesh" {
  description = "Service mesh and observability status"
  value = join("\n", [
    "=============================================================================",
    "SERVICE MESH & OBSERVABILITY", 
    "=============================================================================",
    "",
    "Istio Ambient Mesh Information:",
    "",
    "Status: kubectl describe servicemeshcontroller managed-istio",
    "Pods: kubectl get pods -n istio-system",
    "Kiali Dashboard: https://kiali.${var.domain_name}",
    "Local Access: kubectl port-forward svc/kiali -n istio-system 20001:20001"
  ])
}

output "grafana_dashboards" {
  description = "Grafana dashboard access information"
  value = join("\n", [
    "=============================================================================",
    "GRAFANA DASHBOARDS",
    "=============================================================================", 
    "",
    "Grafana Dashboard Information:",
    "",
    "URL: https://grafana.${var.domain_name}",
    "Credentials: admin / admin",
    "Change default password in production!"
  ])
}

# =============================================================================
# DATABASE PLATFORM OUTPUTS  
# =============================================================================

output "database_platform" {
  description = "Database platform information and test examples"
  value = join("\n", [
    "=============================================================================",
    "DATABASE PLATFORM",
    "=============================================================================",
    "",
    "KubeBlocks Database Platform:",
    "",
    "Namespace: kb-system",
    "Test Examples:",
    "  kubectl apply -f operator-kubeblocks/manifests/test-postgres.yaml",
    "  kubectl apply -f operator-kubeblocks/manifests/test-postgres-ha.yaml", 
    "  kubectl apply -f operator-kubeblocks/manifests/test-redis.yaml",
    "  kubectl apply -f operator-kubeblocks/manifests/test-mongodb.yaml"
  ])
}

# =============================================================================
# MONITORING STACK OUTPUTS
# =============================================================================

output "monitoring_stack" {
  description = "Prometheus monitoring stack information"
  value = join("\n", [
    "=============================================================================",
    "MONITORING STACK",
    "=============================================================================",
    "",
    "Prometheus Operator Monitoring Stack:",
    "",
    "Namespace: monitoring",
    "Access Commands:",
    "  Prometheus: kubectl port-forward svc/kube-prometheus-stack-prometheus -n monitoring 9090:9090",
    "  Alertmanager: kubectl port-forward svc/kube-prometheus-stack-alertmanager -n monitoring 9093:9093",
    "Management:",
    "  ServiceMonitors: kubectl get servicemonitors -A",
    "  PrometheusRules: kubectl get prometheusrules -A"
  ])
}

# =============================================================================
# POLICY & SECURITY OUTPUTS
# =============================================================================

output "policy_security" {
  description = "Security and policy engine information"
  value = join("\n", [
    "=============================================================================",
    "POLICY & SECURITY",
    "=============================================================================",
    "",
    "Kyverno Policy Engine:",
    "",
    "Status: ${coalesce(module.kyverno.kyverno_namespace, "Kyverno is disabled")}",
    "Policy Reporter: ${coalesce(module.kyverno.policy_reporter_url, "Policy Reporter UI is disabled")}",
    "Commands: ${coalesce(module.kyverno.kyverno_status_commands, "Kyverno is disabled")}"
  ])
}

# =============================================================================
# WORKFLOW AUTOMATION OUTPUTS
# =============================================================================

output "workflow_automation" {
  description = "Workflow automation platform information"
  value = join("\n", [
    "=============================================================================",
    "WORKFLOW AUTOMATION",
    "=============================================================================",
    "",
    "Argo Workflows Platform:",
    "",
    "Namespace: ${coalesce(module.argoworkflow.argo_namespace, "Argo Workflows is disabled")}",
    "Dashboard: ${coalesce(module.argoworkflow.argo_workflows_url, "Argo Workflows is disabled")}"
  ])
}

# =============================================================================
# MLOPS PLATFORM OUTPUTS
# =============================================================================

output "mlops_platform" {
  description = "Machine Learning Operations platform information"
  value = join("\n", [
    "=============================================================================",
    "MLOPS PLATFORM",
    "=============================================================================",
    "",
    "ZenML MLOps Platform:",
    "",
    "URL: ${coalesce(module.zenml.zenml_url, "ZenML is disabled")}",
    "Object Store Bucket: ${coalesce(module.zenml.zenml_artifact_bucket_name, "ZenML is disabled")}"
  ])
}

