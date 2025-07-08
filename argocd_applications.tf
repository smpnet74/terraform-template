
resource "kubectl_manifest" "root_app" {
  yaml_body = <<-EOF
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: root-app
  namespace: argocd
spec:
  project: default
  source:
    repoURL: ${github_repository.argocd_apps.html_url}
    path: 'apps'
    targetRevision: HEAD
  destination:
    server: https://kubernetes.default.svc
    namespace: argocd
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
EOF

  depends_on = [
    helm_release.argocd,
    github_repository_file.nginx_app,
    github_repository_file.nginx_manifest,
    module.bookinfo,
    time_sleep.wait_for_cluster
  ]
}

# Bookinfo Application is now managed by the bookinfo module
