# Kiali Bookinfo View Configuration
# This creates a ConfigMap to add a Bookinfo application view in Kiali

resource "kubectl_manifest" "kiali_bookinfo_view" {
  yaml_body = <<-EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: kiali-bookinfo-view
  namespace: istio-system
  labels:
    app: kiali
    app.kubernetes.io/name: kiali
    app.kubernetes.io/part-of: kiali
data:
  bookinfo-view: |
    {
      "name": "bookinfo",
      "title": "Bookinfo Application",
      "description": "Bookinfo sample application with Ambient Mesh",
      "namespace": {
        "name": "bookinfo"
      },
      "items": [
        {
          "type": "service",
          "name": "productpage"
        },
        {
          "type": "service",
          "name": "reviews"
        },
        {
          "type": "service",
          "name": "details"
        },
        {
          "type": "service",
          "name": "ratings"
        }
      ]
    }
EOF

  depends_on = [
    helm_release.kiali,
    kubectl_manifest.bookinfo_app
  ]
}
