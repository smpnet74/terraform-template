resource "kubernetes_ingress_v1" "nginx" {
  metadata {
    name      = "nginx-ingress"
    namespace = "default"
    annotations = {
      "kubernetes.io/ingress.class": "traefik"
    }
  }

  spec {
    rule {
      host = "nginx.${var.domain_name}"
      http {
        path {
          path = "/"
          path_type = "Prefix"
          backend {
            service {
              name = "nginx"
              port {
                number = 80
              }
            }
          }
        }
      }
    }
  }
}
