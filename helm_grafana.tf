resource "helm_release" "grafana" {
  name       = "grafana"
  repository = "https://grafana.github.io/helm-charts"
  chart      = "grafana"
  namespace  = "istio-system"
  create_namespace = false
  
  set {
    name  = "adminPassword"
    value = "admin"  # You can change this to a more secure password
  }
  
  set {
    name  = "datasources.datasources\\.yaml.apiVersion"
    value = "1"
  }
  
  set {
    name  = "datasources.datasources\\.yaml.datasources[0].name"
    value = "Prometheus"
  }
  
  set {
    name  = "datasources.datasources\\.yaml.datasources[0].type"
    value = "prometheus"
  }
  
  set {
    name  = "datasources.datasources\\.yaml.datasources[0].url"
    value = "http://prometheus-server"
  }
  
  set {
    name  = "datasources.datasources\\.yaml.datasources[0].access"
    value = "proxy"
  }
  
  set {
    name  = "datasources.datasources\\.yaml.datasources[0].isDefault"
    value = "true"
  }
  
  # Add some useful Istio dashboards
  set {
    name  = "dashboardProviders.dashboardproviders\\.yaml.apiVersion"
    value = "1"
  }
  
  set {
    name  = "dashboardProviders.dashboardproviders\\.yaml.providers[0].name"
    value = "default"
  }
  
  set {
    name  = "dashboardProviders.dashboardproviders\\.yaml.providers[0].orgId"
    value = "1"
  }
  
  set {
    name  = "dashboardProviders.dashboardproviders\\.yaml.providers[0].type"
    value = "file"
  }
  
  set {
    name  = "dashboardProviders.dashboardproviders\\.yaml.providers[0].disableDeletion"
    value = "false"
  }
  
  set {
    name  = "dashboardProviders.dashboardproviders\\.yaml.providers[0].options.path"
    value = "/var/lib/grafana/dashboards/default"
  }
  
  depends_on = [
    helm_release.prometheus,
    time_sleep.wait_for_prometheus
  ]
}

# Update Kiali to use Grafana
resource "null_resource" "update_kiali_for_grafana" {
  depends_on = [
    helm_release.grafana,
    helm_release.kiali,
    local_file.cluster-config
  ]
  
  provisioner "local-exec" {
    command = <<-EOT
      kubectl patch configmap/kiali -n istio-system --type=merge -p '{"data":{"external_services":"{\"grafana\":{\"enabled\":true,\"in_cluster_url\":\"http://grafana.istio-system:80\",\"url\":\"http://grafana.istio-system:80\"}}"}' --kubeconfig=${path.module}/kubeconfig || true
      kubectl rollout restart deployment/kiali -n istio-system --kubeconfig=${path.module}/kubeconfig
    EOT
  }
}
