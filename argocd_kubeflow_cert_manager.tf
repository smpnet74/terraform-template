# ArgoCD Application for Kubeflow cert-manager (sync wave -1)

resource "kubectl_manifest" "kubeflow_cert_manager_app" {
  yaml_body = <<-EOF
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: kubeflow-cert-manager
  namespace: argocd
  annotations:
    argocd.argoproj.io/sync-wave: "-1"
spec:
  project: default
  source:
    repoURL: ${github_repository.argocd_apps.html_url}
    path: kubeflow/cert-manager
    targetRevision: HEAD
  destination:
    server: https://kubernetes.default.svc
    namespace: cert-manager
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
    github_repository_file.kubeflow_cert_manager_kustomization,
    github_repository_file.kubeflow_cert_manager_namespace,
    kubectl_manifest.kubeflow_crds_app,
    time_sleep.wait_for_cluster
  ]
}
