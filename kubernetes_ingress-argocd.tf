# ArgoCD HTTPRoute for Kgateway
resource "kubectl_manifest" "argocd_httproute" {
  yaml_body = <<-YAML
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: argocd-server-route
  namespace: argocd
spec:
  parentRefs:
  - name: default-gateway
    namespace: default
    kind: Gateway
  hostnames:
  - "test-argocd.${var.domain_name}"
  rules:
  - matches:
    - path:
        type: PathPrefix
        value: /
    backendRefs:
    - name: argocd-server
      port: 80
      kind: Service
  YAML

  depends_on = [
    helm_release.argocd,
    kubectl_manifest.default_gateway,
    kubernetes_secret.cloudflare_origin_cert
  ]
}
