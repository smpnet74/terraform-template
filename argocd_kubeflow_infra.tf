# ArgoCD Application for Kubeflow Infrastructure (sync wave 0)

resource "kubectl_manifest" "kubeflow_infra_app" {
  yaml_body = <<-EOF
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: kubeflow-infrastructure
  namespace: argocd
  annotations:
    argocd.argoproj.io/sync-wave: "0"
spec:
  project: default
  source:
    repoURL: ${github_repository.argocd_apps.html_url}
    path: kubeflow/infrastructure
    targetRevision: HEAD
  destination:
    server: https://kubernetes.default.svc
    namespace: kubeflow
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
      - ServerSideApply=true
    retry:
      limit: 5
      backoff:
        duration: 5s
        factor: 2
        maxDuration: 3m
EOF

  depends_on = [
    helm_release.argocd,
    github_repository_file.kubeflow_infra_kustomization,
    kubectl_manifest.kubeflow_cert_manager_app,
    time_sleep.wait_for_cluster
  ]
}
