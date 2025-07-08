# Kubeflow CRDs (sync wave -2)

# Create the kubeflow-crds directory structure
resource "github_repository_file" "kubeflow_crds_kustomization" {
  count      = var.enable_kubeflow ? 1 : 0
  repository = var.github_repo_name
  file       = "kubeflow/crds/kustomization.yaml"
  content    = <<-EOF
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
- namespace.yaml
EOF
  
  depends_on = [var.github_repository]
}

# Create the kubeflow namespace definition
resource "github_repository_file" "kubeflow_crds_namespace" {
  count      = var.enable_kubeflow ? 1 : 0
  repository = var.github_repo_name
  file       = "kubeflow/crds/namespace.yaml"
  content    = <<-EOF
apiVersion: v1
kind: Namespace
metadata:
  name: kubeflow
  labels:
    control-plane: kubeflow
    istio-injection: enabled
EOF
  
  depends_on = [var.github_repository]
}

# ArgoCD Application for Kubeflow CRDs
resource "kubectl_manifest" "kubeflow_crds_app" {
  count     = var.enable_kubeflow ? 1 : 0
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
    repoURL: ${var.github_repo_url}
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
    var.argocd_helm_release,
    github_repository_file.kubeflow_crds_kustomization[0],
    github_repository_file.kubeflow_crds_namespace[0]
  ]
}
