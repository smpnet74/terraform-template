resource "kubernetes_ingress_v1" "argocd" {
  metadata {
    name      = "argocd-server-ingress"
    namespace = "argocd"
    annotations = {
      "kubernetes.io/ingress.class"    = "traefik"
      "cert-manager.io/cluster-issuer" = "letsencrypt-staging"
    }
  }

  spec {
    rule {
      host = "test-argocd.${var.domain_name}"
      http {
        path {
          path_type = "Prefix"
          path      = "/"
          backend {
            service {
              name = "argocd-server"
              port {
                number = 80
              }
            }
          }
        }
      }
    }
    tls {
      hosts      = ["test-argocd.${var.domain_name}"]
      secret_name = "argocd-tls"
    }
  }

  depends_on = [
    helm_release.argocd,
    helm_release.traefik_ingress,
    kubectl_manifest.letsencrypt_issuer,
  ]
}
