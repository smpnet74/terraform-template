resource "kubectl_manifest" "grafana_httproute" {
  yaml_body = <<-EOF
    apiVersion: gateway.networking.k8s.io/v1
    kind: HTTPRoute
    metadata:
      name: grafana-route
      namespace: istio-system
    spec:
      parentRefs:
      - name: default-gateway
        namespace: default
        kind: Gateway
      hostnames:
      - "grafana.${var.domain_name}"
      rules:
      - matches:
        - path:
            type: PathPrefix
            value: /
        backendRefs:
        - name: grafana
          port: 80
  EOF

  depends_on = [
    helm_release.grafana,
    kubectl_manifest.default_gateway
  ]
}
