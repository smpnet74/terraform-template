resource "helm_release" "grafana" {
  name       = "grafana"
  repository = "https://grafana.github.io/helm-charts"
  chart      = "grafana"
  namespace  = "istio-system"
  create_namespace = true
  
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
    value = var.enable_prometheus_operator ? "http://kube-prometheus-stack-prometheus.${var.monitoring_namespace}:9090" : "http://prometheus-server"
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

  # Pre-configured dashboards for our cloud-native stack
  set {
    name  = "dashboards.default.kubernetes-cluster-monitoring.gnetId"
    value = "7249"  # Kubernetes Cluster Monitoring (via Prometheus)
  }
  
  set {
    name  = "dashboards.default.kubernetes-cluster-monitoring.revision"
    value = "1"
  }
  
  set {
    name  = "dashboards.default.kubernetes-cluster-monitoring.datasource"
    value = "Prometheus"
  }

  set {
    name  = "dashboards.default.node-exporter.gnetId"
    value = "1860"  # Node Exporter Full
  }
  
  set {
    name  = "dashboards.default.node-exporter.revision"
    value = "37"
  }
  
  set {
    name  = "dashboards.default.node-exporter.datasource"
    value = "Prometheus"
  }

  set {
    name  = "dashboards.default.kubernetes-pods.gnetId"
    value = "6417"  # Kubernetes Pods
  }
  
  set {
    name  = "dashboards.default.kubernetes-pods.revision"
    value = "1"
  }
  
  set {
    name  = "dashboards.default.kubernetes-pods.datasource"
    value = "Prometheus"
  }

  set {
    name  = "dashboards.default.istio-control-plane.gnetId"
    value = "7645"  # Istio Control Plane Dashboard
  }
  
  set {
    name  = "dashboards.default.istio-control-plane.revision"
    value = "1"
  }
  
  set {
    name  = "dashboards.default.istio-control-plane.datasource"
    value = "Prometheus"
  }

  set {
    name  = "dashboards.default.istio-mesh.gnetId"
    value = "7639"  # Istio Mesh Dashboard
  }
  
  set {
    name  = "dashboards.default.istio-mesh.revision"
    value = "1"
  }
  
  set {
    name  = "dashboards.default.istio-mesh.datasource"
    value = "Prometheus"
  }

  set {
    name  = "dashboards.default.cilium-agent.gnetId"
    value = "16611"  # Cilium Metrics
  }
  
  set {
    name  = "dashboards.default.cilium-agent.revision"
    value = "1"
  }
  
  set {
    name  = "dashboards.default.cilium-agent.datasource"
    value = "Prometheus"
  }

  set {
    name  = "dashboards.default.prometheus-stats.gnetId"
    value = "2"  # Prometheus 2.0 Stats
  }
  
  set {
    name  = "dashboards.default.prometheus-stats.revision"
    value = "2"
  }
  
  set {
    name  = "dashboards.default.prometheus-stats.datasource"
    value = "Prometheus"
  }

  set {
    name  = "dashboards.default.kubernetes-apiserver.gnetId"
    value = "12006"  # Kubernetes API Server
  }
  
  set {
    name  = "dashboards.default.kubernetes-apiserver.revision"
    value = "1"
  }
  
  set {
    name  = "dashboards.default.kubernetes-apiserver.datasource"
    value = "Prometheus"
  }

  set {
    name  = "dashboards.default.kube-state-metrics.gnetId"
    value = "13332"  # Kube State Metrics v2
  }
  
  set {
    name  = "dashboards.default.kube-state-metrics.revision"
    value = "12"
  }
  
  set {
    name  = "dashboards.default.kube-state-metrics.datasource"
    value = "Prometheus"
  }

  set {
    name  = "dashboards.default.alertmanager.gnetId"
    value = "9578"  # Alertmanager
  }
  
  set {
    name  = "dashboards.default.alertmanager.revision"
    value = "4"
  }
  
  set {
    name  = "dashboards.default.alertmanager.datasource"
    value = "Prometheus"
  }
  
  depends_on = [
    # This will implicitly wait for whichever Prometheus is enabled
    # Terraform will handle the dependencies correctly
  ]
}

# Update Kiali to use Grafana
resource "null_resource" "update_kiali_for_grafana" {
  depends_on = [
    helm_release.grafana,
    module.kiali,
    local_file.cluster-config
  ]
  
  provisioner "local-exec" {
    command = <<-EOT
      kubectl patch configmap/kiali -n istio-system --type=merge -p '{"data":{"external_services":"{\"grafana\":{\"enabled\":true,\"in_cluster_url\":\"http://grafana.istio-system:80\",\"url\":\"http://grafana.istio-system:80\"}}"}' --kubeconfig=${path.module}/kubeconfig || true
      kubectl rollout restart deployment/kiali -n istio-system --kubeconfig=${path.module}/kubeconfig
    EOT
  }
}
