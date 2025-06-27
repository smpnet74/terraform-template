resource "kubernetes_namespace" "cert_manager" {
  metadata {
    name = "cert-manager"
  }
}

resource "helm_release" "cert_manager" {
  name       = "cert-manager"
  repository = "https://charts.jetstack.io"
  chart      = "cert-manager"
  namespace  = kubernetes_namespace.cert_manager.metadata[0].name
  version    = "v1.15.1"
  
  # Add timeout to prevent indefinite waiting
  timeout = 900  # 15 minutes
  
  # Set atomic to false to prevent rollback on timeout
  atomic = false

  set {
    name  = "installCRDs"
    value = "true"
  }

  depends_on = [
    kubernetes_namespace.cert_manager,
    null_resource.cilium_upgrade,  # Ensure Cilium is fully deployed first
    time_sleep.wait_for_cluster    # Ensure cluster is ready
  ]
}
