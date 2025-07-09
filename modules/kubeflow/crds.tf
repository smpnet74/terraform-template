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
- notebook-crd.yaml
- profile-crd.yaml
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
    istio.io/dataplane-mode: ambient
EOF
  
  depends_on = [var.github_repository]
}

# Create the Kubeflow CRDs file for notebook controller
resource "github_repository_file" "kubeflow_notebook_crds" {
  count      = var.enable_kubeflow ? 1 : 0
  repository = var.github_repo_name
  file       = "kubeflow/crds/notebook-crd.yaml"
  content    = <<-EOF
apiVersion: apiextensions.k8s.io/v1
kind: CustomResourceDefinition
metadata:
  name: notebooks.kubeflow.org
spec:
  group: kubeflow.org
  names:
    kind: Notebook
    plural: notebooks
    singular: notebook
  scope: Namespaced
  versions:
  - name: v1beta1
    served: true
    storage: false
    schema:
      openAPIV3Schema:
        type: object
        properties:
          apiVersion:
            type: string
          kind:
            type: string
          metadata:
            type: object
          spec:
            type: object
            properties:
              template:
                type: object
                properties:
                  spec:
                    type: object
                    properties:
                      containers:
                        type: array
                        items:
                          type: object
                          properties:
                            image:
                              type: string
          status:
            type: object
            properties:
              conditions:
                type: array
                items:
                  type: object
                  properties:
                    type:
                      type: string
                    status:
                      type: string
                    message:
                      type: string
                    reason:
                      type: string
                    lastTransitionTime:
                      type: string
                    lastUpdateTime:
                      type: string
              readyReplicas:
                type: integer
    subresources:
      status: {}
  - name: v1
    served: true
    storage: true
    schema:
      openAPIV3Schema:
        type: object
        properties:
          apiVersion:
            type: string
          kind:
            type: string
          metadata:
            type: object
          spec:
            type: object
            properties:
              template:
                type: object
                properties:
                  spec:
                    type: object
                    properties:
                      containers:
                        type: array
                        items:
                          type: object
                          properties:
                            image:
                              type: string
          status:
            type: object
            properties:
              conditions:
                type: array
                items:
                  type: object
                  properties:
                    type:
                      type: string
                    status:
                      type: string
                    message:
                      type: string
                    reason:
                      type: string
                    lastTransitionTime:
                      type: string
                    lastUpdateTime:
                      type: string
              readyReplicas:
                type: integer
    subresources:
      status: {}
EOF

  depends_on = [var.github_repository]
}

# Create the Kubeflow CRDs file for profiles
resource "github_repository_file" "kubeflow_profile_crds" {
  count      = var.enable_kubeflow ? 1 : 0
  repository = var.github_repo_name
  file       = "kubeflow/crds/profile-crd.yaml"
  content    = <<-EOF
apiVersion: apiextensions.k8s.io/v1
kind: CustomResourceDefinition
metadata:
  name: profiles.kubeflow.org
spec:
  group: kubeflow.org
  names:
    kind: Profile
    plural: profiles
    singular: profile
  scope: Cluster
  versions:
  - name: v1
    served: true
    storage: true
    schema:
      openAPIV3Schema:
        type: object
        properties:
          apiVersion:
            type: string
          kind:
            type: string
          metadata:
            type: object
          spec:
            type: object
            properties:
              owner:
                type: object
                properties:
                  kind:
                    type: string
                  name:
                    type: string
          status:
            type: object
    subresources:
      status: {}
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
  finalizers:
    - resources-finalizer.argocd.argoproj.io
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
  ignoreDifferences:
    - group: apiextensions.k8s.io
      kind: CustomResourceDefinition
      jsonPointers:
        - /metadata/labels
        - /spec/names/shortNames
EOF

  depends_on = [
    var.argocd_helm_release,
    github_repository_file.kubeflow_crds_kustomization[0],
    github_repository_file.kubeflow_crds_namespace[0],
    github_repository_file.kubeflow_notebook_crds[0],
    github_repository_file.kubeflow_profile_crds[0]
  ]
}
