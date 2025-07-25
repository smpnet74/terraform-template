# Kiali Service Mesh Observability Feature Module
# Deploys Kiali for service mesh visualization and optionally a basic Prometheus when Prometheus Operator is disabled

# 1. Deploy Kiali Service Mesh Observability Dashboard
resource "helm_release" "kiali" {
  name       = "kiali"
  repository = "https://kiali.org/helm-charts"
  chart      = "kiali-server"
  namespace  = "istio-system"
  create_namespace = true
  
  set {
    name  = "auth.strategy"
    value = "anonymous"
  }
  
  set {
    name  = "deployment.ingress.enabled"
    value = "false"
  }
  
  set {
    name  = "external_services.prometheus.url"
    value = var.enable_prometheus_operator ? "http://kube-prometheus-stack-prometheus.${var.monitoring_namespace}:9090" : "http://prometheus-server.istio-system:80"
  }
  
  # Configure Grafana integration
  set {
    name  = "external_services.grafana.enabled"
    value = "true"
  }
  
  set {
    name  = "external_services.grafana.in_cluster_url"
    value = "http://grafana.istio-system:80"
  }
  
  set {
    name  = "external_services.grafana.url"
    value = "http://grafana.istio-system:80"
  }
    
  # Configure Gateway API support
  values = [
    <<-EOT
    external_services:
      istio:
        gateway_api_classes:
          - name: "gateway.networking.k8s.io/v1"
    EOT
  ]
  
  # Dependencies are handled at the module call level
}

# 2. Deploy basic Prometheus when Prometheus Operator is disabled
resource "helm_release" "prometheus" {
  count      = var.enable_prometheus_operator ? 0 : 1  # Only deploy when Prometheus Operator is disabled
  name       = "prometheus"
  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "prometheus"
  namespace  = "istio-system"
  create_namespace = true
  
  set {
    name  = "server.persistentVolume.enabled"
    value = "false"
  }
  
  set {
    name  = "alertmanager.enabled"
    value = "false"
  }
  
  set {
    name  = "pushgateway.enabled"
    value = "false"
  }
  
  # Dependencies are handled at the module call level
}

# 3. Add a wait for basic Prometheus to be ready before Kiali uses it
resource "time_sleep" "wait_for_prometheus" {
  count = var.enable_prometheus_operator ? 0 : 1  # Only when basic Prometheus is deployed
  depends_on = [helm_release.prometheus[0]]
  create_duration = "30s"
}

# 4. Update Kiali to depend on basic Prometheus when needed
resource "null_resource" "kiali_depends_on_prometheus" {
  count = var.enable_prometheus_operator ? 0 : 1  # Only needed for basic Prometheus setup
  depends_on = [
    helm_release.prometheus[0],
    time_sleep.wait_for_prometheus[0],
    helm_release.kiali
  ]
}

# 5. Configure HTTPRoute for Kiali access via Gateway API
resource "kubectl_manifest" "kiali_httproute" {
  yaml_body = templatefile("${path.module}/manifests/kiali-httproute.yaml", {
    domain_name = var.domain_name
  })

  depends_on = [
    helm_release.kiali
    # Gateway dependencies handled at module level
  ]
}