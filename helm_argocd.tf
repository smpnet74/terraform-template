resource "kubernetes_namespace" "argocd" {
  metadata {
    name = "argocd"
  }
}

resource "helm_release" "argocd" {
  name       = "argocd"
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-cd"
  namespace  = kubernetes_namespace.argocd.metadata[0].name
  version    = "7.3.8"

  wait    = true
  atomic  = false  # Set to false to prevent rollback on timeout
  timeout = 900    # 15 minutes

  # The key insight: server.insecure must be set as an extraArg with empty string value
  # And the URL must be set in the ConfigMap (cm) section
  values = [
    <<-EOF
    server:
      extraArgs:
        - --insecure

    configs:
      cm:
        url: https://test-argocd.${var.domain_name}
    EOF
  ]

  depends_on = [
    kubernetes_namespace.argocd,
    helm_release.kgateway,  # Ensure Kgateway is deployed first
    time_sleep.wait_for_service_mesh_controller  # Ensure Ambient Mesh is deployed first
  ]
}
