# GitHub repository files for Kubeflow CRDs (sync wave -2)

# Create the kubeflow-crds directory structure
resource "github_repository_file" "kubeflow_crds_kustomization" {
  repository = github_repository.argocd_apps.name
  file       = "kubeflow/crds/kustomization.yaml"
  content    = <<-EOF
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
- namespace.yaml
EOF

  depends_on = [github_repository.argocd_apps]
}

# Create the kubeflow namespace definition
resource "github_repository_file" "kubeflow_crds_namespace" {
  repository = github_repository.argocd_apps.name
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

  depends_on = [github_repository.argocd_apps]
}


