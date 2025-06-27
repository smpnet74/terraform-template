resource "kubectl_manifest" "gateway_certificate" {
  yaml_body = <<-YAML
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: default-gateway-cert
  namespace: default
spec:
  secretName: default-gateway-cert
  issuerRef:
    name: letsencrypt-prod
    kind: ClusterIssuer
  dnsNames:
  - "*.${var.domain_name}"
  YAML

  depends_on = [
    kubectl_manifest.letsencrypt_prod_issuer,
    helm_release.cert_manager,
    cloudflare_dns_record.wildcard
  ]
}
