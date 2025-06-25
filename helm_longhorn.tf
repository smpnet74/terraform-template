resource "kubernetes_namespace" "longhorn_system" {
  metadata {
    name = "longhorn-system"
  }
}

resource "helm_release" "longhorn" {
  name       = "longhorn"
  repository = "https://charts.longhorn.io"
  chart      = "longhorn"
  namespace  = kubernetes_namespace.longhorn_system.metadata.0.name
  version    = "1.8.2"

  depends_on = [
    civo_kubernetes_cluster.cluster
  ]
}
