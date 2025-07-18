# KubeBlocks - Cloud Native Database Management Platform
# https://www.kubeblocks.io/docs/preview/user_docs/overview/install-kubeblocks

# Create namespace for KubeBlocks
resource "kubernetes_namespace" "kb_system" {
  metadata {
    name = "kb-system"
    labels = {
      "app.kubernetes.io/name" = "kubeblocks"
      "app.kubernetes.io/part-of" = "kubeblocks"
    }
  }
}

# Install KubeBlocks CRDs
resource "null_resource" "kubeblocks_crds" {
  provisioner "local-exec" {
    command = "kubectl create -f https://github.com/apecloud/kubeblocks/releases/download/v1.0.0/kubeblocks_crds.yaml --validate=false --kubeconfig=${path.module}/kubeconfig || true"
  }
  
  depends_on = [
    kubernetes_namespace.kb_system,
    local_file.cluster-config
  ]
}

# Wait for KubeBlocks CRDs to be ready
resource "time_sleep" "wait_for_kubeblocks_crds" {
  depends_on = [null_resource.kubeblocks_crds]
  create_duration = "30s"
}

# Install KubeBlocks via Helm
resource "helm_release" "kubeblocks" {
  name       = "kubeblocks"
  repository = "https://apecloud.github.io/helm-charts"
  chart      = "kubeblocks"
  version    = "1.0.0"
  namespace  = "kb-system"
  
  # Basic configuration
  set {
    name  = "installCRDs"
    value = "false"  # We're installing CRDs separately
  }
  
  # Resource configuration
  set {
    name  = "resources.requests.cpu"
    value = "100m"
  }
  
  set {
    name  = "resources.requests.memory"
    value = "256Mi"
  }
  
  set {
    name  = "resources.limits.cpu"
    value = "500m"
  }
  
  set {
    name  = "resources.limits.memory"
    value = "512Mi"
  }
  
  # Integration with existing infrastructure
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
    time_sleep.wait_for_kubeblocks_crds,
    kubernetes_namespace.kb_system
  ]
}