resource "kubectl_manifest" "kiali_httproute" {
  yaml_body = <<-EOF
    apiVersion: gateway.networking.k8s.io/v1
    kind: HTTPRoute
    metadata:
      name: kiali-route
      namespace: istio-system
    spec:
      parentRefs:
      - name: default-gateway
        namespace: default
        kind: Gateway
      hostnames:
      - "kiali.${var.domain_name}"
      rules:
      - matches:
        - path:
            type: PathPrefix
            value: /
        backendRefs:
        - name: kiali
          port: 20001
  EOF

  depends_on = [
    helm_release.kiali,
    kubectl_manifest.default_gateway
  ]
}
