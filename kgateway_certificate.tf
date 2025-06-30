# Cloudflare Origin Certificate Configuration

# Create Kubernetes secret for Cloudflare Origin Certificate using local files
resource "kubernetes_secret" "cloudflare_origin_cert" {
  metadata {
    name      = "default-gateway-cert"
    namespace = "default"
  }

  type = "kubernetes.io/tls"

  data = {
    "tls.crt" = file("${path.module}/certs/tls.crt")
    "tls.key" = file("${path.module}/certs/tls.key")
  }

  depends_on = [
    civo_kubernetes_cluster.cluster,
    time_sleep.wait_for_cluster
  ]
}

# Note: We're no longer using cert-manager for certificates
# Instead, we're using Cloudflare Origin Certificates directly as a Kubernetes secret
