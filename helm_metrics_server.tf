# Metrics Server - Kubernetes resource utilization metrics
# https://github.com/kubernetes-sigs/metrics-server

resource "helm_release" "metrics_server" {
  name       = "metrics-server"
  repository = "https://kubernetes-sigs.github.io/metrics-server/"
  chart      = "metrics-server"
  version    = var.metrics_server_chart_version
  namespace  = "kube-system"
  create_namespace = false

  # Required for Civo and other cloud providers where kubelet certificates
  # might not be properly configured for metrics server
  set {
    name  = "args"
    value = "{--kubelet-insecure-tls}"
  }

  # Resource configuration
  set {
    name  = "resources.requests.cpu"
    value = "100m"
  }

  set {
    name  = "resources.requests.memory"
    value = "200Mi"
  }

  set {
    name  = "resources.limits.cpu"
    value = "200m"
  }

  set {
    name  = "resources.limits.memory"
    value = "400Mi"
  }

  # High availability for production
  set {
    name  = "replicas"
    value = "2"
  }

  # Security context
  set {
    name  = "securityContext.runAsNonRoot"
    value = "true"
  }

  set {
    name  = "securityContext.runAsUser"
    value = "1000"
  }

  # Tolerations for scheduling
  set {
    name  = "tolerations[0].key"
    value = "node-role.kubernetes.io/control-plane"
  }

  set {
    name  = "tolerations[0].operator"
    value = "Exists"
  }

  set {
    name  = "tolerations[0].effect"
    value = "NoSchedule"
  }

  depends_on = [
    time_sleep.wait_for_cluster
  ]
}