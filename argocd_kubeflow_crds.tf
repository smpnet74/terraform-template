# ArgoCD Application for Kubeflow CRDs (sync wave -2)

resource "kubectl_manifest" "kubeflow_crds_app" {
  yaml_body = <<-EOF
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: kubeflow-crds
  namespace: argocd
  annotations:
    argocd.argoproj.io/sync-wave: "-2"
spec:
  project: default
  source:
    repoURL: ${github_repository.argocd_apps.html_url}
    path: kubeflow/crds
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
    github_repository_file.kubeflow_crds_kustomization,
    time_sleep.wait_for_cluster
  ]
}
