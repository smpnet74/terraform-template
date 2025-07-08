# GitHub repository files for Kubeflow cert-manager (sync wave -1)

# Create the cert-manager directory structure
resource "github_repository_file" "kubeflow_cert_manager_kustomization" {
  repository = github_repository.argocd_apps.name
  file       = "kubeflow/cert-manager/kustomization.yaml"
  content    = <<-EOF
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

namespace: cert-manager

resources:
- namespace.yaml
- cert-manager-crds.yaml
- cert-manager-deployment.yaml
EOF

  depends_on = [github_repository.argocd_apps]
}

# Create the cert-manager namespace definition
resource "github_repository_file" "kubeflow_cert_manager_namespace" {
  repository = github_repository.argocd_apps.name
  file       = "kubeflow/cert-manager/namespace.yaml"
  content    = <<-EOF
apiVersion: v1
kind: Namespace
metadata:
  name: cert-manager
EOF

  depends_on = [github_repository.argocd_apps]
}

# Create the cert-manager CRDs file
resource "github_repository_file" "kubeflow_cert_manager_crds" {
  repository = github_repository.argocd_apps.name
  file       = "kubeflow/cert-manager/cert-manager-crds.yaml"
  content    = <<-EOF
# Cert Manager CRDs
apiVersion: apiextensions.k8s.io/v1
kind: CustomResourceDefinition
metadata:
  name: certificaterequests.cert-manager.io
spec:
  group: cert-manager.io
  names:
    kind: CertificateRequest
    plural: certificaterequests
    singular: certificaterequest
    shortNames:
    - cr
  scope: Namespaced
  versions:
  - name: v1
    served: true
    storage: true
    schema:
      openAPIV3Schema:
        type: object
        properties:
          spec:
            type: object
---
apiVersion: apiextensions.k8s.io/v1
kind: CustomResourceDefinition
metadata:
  name: certificates.cert-manager.io
spec:
  group: cert-manager.io
  names:
    kind: Certificate
    plural: certificates
    singular: certificate
    shortNames:
    - cert
  scope: Namespaced
  versions:
  - name: v1
    served: true
    storage: true
    schema:
      openAPIV3Schema:
        type: object
---
apiVersion: apiextensions.k8s.io/v1
kind: CustomResourceDefinition
metadata:
  name: issuers.cert-manager.io
spec:
  group: cert-manager.io
  names:
    kind: Issuer
    plural: issuers
    singular: issuer
  scope: Namespaced
  versions:
  - name: v1
    served: true
    storage: true
    schema:
      openAPIV3Schema:
        type: object
EOF

  depends_on = [github_repository.argocd_apps]
}

# Create the cert-manager deployment file
resource "github_repository_file" "kubeflow_cert_manager_deployment" {
  repository = github_repository.argocd_apps.name
  file       = "kubeflow/cert-manager/cert-manager-deployment.yaml"
  content    = <<-EOF
# Cert Manager Deployment
apiVersion: v1
kind: ServiceAccount
metadata:
  name: cert-manager
  namespace: cert-manager
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: cert-manager
rules:
- apiGroups: ["cert-manager.io"]
  resources: ["*"]
  verbs: ["*"]
- apiGroups: [""]
  resources: ["secrets", "configmaps", "services"]
  verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: cert-manager
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cert-manager
subjects:
- kind: ServiceAccount
  name: cert-manager
  namespace: cert-manager
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: cert-manager
  namespace: cert-manager
  labels:
    app: cert-manager
spec:
  replicas: 1
  selector:
    matchLabels:
      app: cert-manager
  template:
    metadata:
      labels:
        app: cert-manager
    spec:
      serviceAccountName: cert-manager
      containers:
      - name: cert-manager
        image: quay.io/jetstack/cert-manager-controller:v1.13.3
        args:
        - --v=2
        - --cluster-resource-namespace=$(POD_NAMESPACE)
        env:
        - name: POD_NAMESPACE
          valueFrom:
            fieldRef:
              fieldPath: metadata.namespace
EOF

  depends_on = [github_repository.argocd_apps]
}
