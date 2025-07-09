# Kubeflow Infrastructure (sync wave 0)

# Create the infrastructure directory structure
resource "github_repository_file" "kubeflow_infra_kustomization" {
  count      = var.enable_kubeflow ? 1 : 0
  repository = var.github_repo_name
  file       = "kubeflow/infrastructure/kustomization.yaml"
  content    = <<-EOF
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

namespace: kubeflow

resources:
- kubeflow-roles.yaml
- test-service.yaml
EOF
}

# Create the Kubeflow RBAC roles
resource "github_repository_file" "kubeflow_infra_roles" {
  count      = var.enable_kubeflow ? 1 : 0
  repository = var.github_repo_name
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
}

# Create the test service for Kubeflow
resource "github_repository_file" "kubeflow_test_service" {
  count      = var.enable_kubeflow ? 1 : 0
  repository = var.github_repo_name
  file       = "kubeflow/infrastructure/test-service.yaml"
  content    = <<-EOF
apiVersion: v1
kind: Service
metadata:
  name: kubeflow-dashboard
  namespace: kubeflow
spec:
  ports:
  - port: 80
    protocol: TCP
    targetPort: 8080
  selector:
    app: kubeflow-test
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: kubeflow-test
  namespace: kubeflow
spec:
  replicas: 1
  selector:
    matchLabels:
      app: kubeflow-test
  template:
    metadata:
      labels:
        app: kubeflow-test
    spec:
      containers:
      - name: nginx
        image: nginx:stable
        ports:
        - containerPort: 8080
          name: http
        volumeMounts:
        - name: nginx-config
          mountPath: /etc/nginx/conf.d
      volumes:
      - name: nginx-config
        configMap:
          name: nginx-test-config
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: nginx-test-config
  namespace: kubeflow
data:
  default.conf: |
    server {
        listen 8080;
        server_name _;
        
        location / {
            add_header Content-Type text/html;
            return 200 '<html><body><h1>Kubeflow Gateway Test</h1><p>The gateway is working correctly!</p></body></html>';
        }
    }
EOF
}

# ArgoCD Application for Kubeflow Infrastructure
resource "kubectl_manifest" "kubeflow_infra_app" {
  count     = var.enable_kubeflow ? 1 : 0
  yaml_body = <<-EOF
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: kubeflow-infrastructure
  namespace: argocd
  annotations:
    argocd.argoproj.io/sync-wave: "0"
  finalizers:
    - resources-finalizer.argocd.argoproj.io
spec:
  project: default
  source:
    repoURL: ${var.github_repo_url}
    path: kubeflow/infrastructure
    targetRevision: HEAD
  destination:
    server: https://kubernetes.default.svc
    namespace: kubeflow
  dependsOn:
    - name: kubeflow-cert-manager
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
    - group: ""
      kind: Namespace
      name: kubeflow
      jsonPointers:
        - /metadata/labels
    - group: "gateway.networking.k8s.io"
      kind: HTTPRoute
      name: kubeflow-route
      namespace: kubeflow
      jsonPointers:
        - /spec
EOF

  depends_on = [
    var.argocd_helm_release,
    kubectl_manifest.kubeflow_cert_manager_app[0],
    var.service_mesh_controller,
    var.wait_for_service_mesh_controller
  ]
}
