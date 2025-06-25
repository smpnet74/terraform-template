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

  wait   = true
  atomic = true

  # The key insight: server.insecure must be set as an extraArg with empty string value
  # And the URL must be set in the ConfigMap (cm) section
  values = [
    <<-EOF
    server:
      extraArgs:
        - --insecure

    configs:
      cm:
        url: https://argocd.${var.domain_name}
    EOF
  ]

  depends_on = [
    kubernetes_namespace.argocd,
  ]
}
