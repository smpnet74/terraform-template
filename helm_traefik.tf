resource "helm_release" "traefik_ingress" {
  name       = "traefik"
  repository = "https://helm.traefik.io/traefik"
  chart      = "traefik"
  namespace  = "traefik"
  version    = "25.0.0"

  create_namespace = true

  depends_on = [
    civo_kubernetes_cluster.cluster
  ]
}
