resource "helm_release" "kiali" {
  name       = "kiali"
  repository = "https://kiali.org/helm-charts"
  chart      = "kiali-server"
  namespace  = "istio-system"
  create_namespace = false
  
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
    value = "http://prometheus-server.istio-system:80"
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
  
  depends_on = [
    kubectl_manifest.service_mesh_controller,
    time_sleep.wait_for_service_mesh_controller,
    helm_release.grafana
  ]
}

resource "helm_release" "prometheus" {
  name       = "prometheus"
  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "prometheus"
  namespace  = "istio-system"
  create_namespace = false
  
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
  
  depends_on = [
    kubectl_manifest.service_mesh_controller,
    time_sleep.wait_for_service_mesh_controller
  ]
}

# Add a wait for Prometheus to be ready before installing Kiali
resource "time_sleep" "wait_for_prometheus" {
  depends_on = [helm_release.prometheus]
  create_duration = "30s"
}

# Update Kiali to depend on Prometheus
resource "null_resource" "kiali_depends_on_prometheus" {
  depends_on = [
    helm_release.prometheus,
    time_sleep.wait_for_prometheus,
    helm_release.kiali
  ]
}
