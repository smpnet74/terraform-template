# GitHub repository files for Kubeflow Infrastructure (sync wave 0)

# Create the infrastructure directory structure
resource "github_repository_file" "kubeflow_infra_kustomization" {
  repository = github_repository.argocd_apps.name
  file       = "kubeflow/infrastructure/kustomization.yaml"
  content    = <<-EOF
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

namespace: kubeflow

resources:
- gateway.yaml
- kubeflow-roles.yaml
- test-service.yaml
EOF

  depends_on = [github_repository.argocd_apps]
}

# Create the Kubeflow Gateway configuration
resource "github_repository_file" "kubeflow_infra_gateway" {
  repository = github_repository.argocd_apps.name
  file       = "kubeflow/infrastructure/gateway.yaml"
  content    = <<-EOF
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: kubeflow-route
  namespace: kubeflow
spec:
  hostnames:
  - "kubeflow.timbersedgearb.com"
  parentRefs:
  - group: gateway.networking.k8s.io
    kind: Gateway
    name: default-gateway
    namespace: default
  rules:
  - backendRefs:
    - group: ""
      kind: Service
      name: kubeflow-dashboard
      port: 80
      weight: 1
    matches:
    - path:
        type: PathPrefix
        value: /
EOF

  depends_on = [github_repository.argocd_apps]
}



# Create the Kubeflow RBAC roles
resource "github_repository_file" "kubeflow_infra_roles" {
  repository = github_repository.argocd_apps.name
  file       = "kubeflow/infrastructure/kubeflow-roles.yaml"
  content    = <<-EOF
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: kubeflow-admin
rules:
- apiGroups: [""]
  resources: ["namespaces", "pods", "services", "configmaps", "secrets"]
  verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
- apiGroups: ["apps"]
  resources: ["deployments", "statefulsets"]
  verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
- apiGroups: ["networking.istio.io"]
  resources: ["virtualservices", "destinationrules", "gateways"]
  verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: kubeflow-admin-binding
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: kubeflow-admin
subjects:
- kind: ServiceAccount
  name: default
  namespace: kubeflow
EOF

  depends_on = [github_repository.argocd_apps]
}


