resource "kubernetes_secret" "cloudflare_api_token_secret" {
  metadata {
    name      = "cloudflare-api-token-secret"
    namespace = kubernetes_namespace.cert_manager.metadata[0].name
  }

  data = {
    "api-token" = var.cloudflare_api_token
  }

  type = "Opaque"

  depends_on = [
    helm_release.cert_manager,
  ]
}

resource "kubectl_manifest" "letsencrypt_issuer" {
  yaml_body = <<-EOF
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-staging
spec:
  acme:
    server: https://acme-staging-v02.api.letsencrypt.org/directory
    email: ${var.cloudflare_email}
    privateKeySecretRef:
      name: letsencrypt-staging
    solvers:
    - dns01:
        cloudflare:
          email: ${var.cloudflare_email}
          apiTokenSecretRef:
            name: ${kubernetes_secret.cloudflare_api_token_secret.metadata[0].name}
            key: api-token
EOF

  depends_on = [
    kubernetes_secret.cloudflare_api_token_secret,
  ]
}

resource "kubectl_manifest" "letsencrypt_prod_issuer" {
  yaml_body = <<-EOF
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: ${var.cloudflare_email}
    privateKeySecretRef:
      name: letsencrypt-prod
    solvers:
    - dns01:
        cloudflare:
          email: ${var.cloudflare_email}
          apiTokenSecretRef:
            name: ${kubernetes_secret.cloudflare_api_token_secret.metadata[0].name}
            key: api-token
EOF

  depends_on = [
    kubernetes_secret.cloudflare_api_token_secret,
  ]
}

