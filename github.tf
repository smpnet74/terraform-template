provider "github" {
  token = var.github_token
}

resource "github_repository" "argocd_apps" {
  name        = var.github_repo_name
  description = "Kubernetes application configurations managed by Argo CD"
  visibility  = "public"
}

resource "github_repository_file" "nginx_app" {
  repository = github_repository.argocd_apps.name
  file       = "apps/nginx.yaml"
  content    = <<-EOF
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: nginx
  namespace: argocd
spec:
  project: default
  source:
    repoURL: ${github_repository.argocd_apps.html_url}
    path: 'nginx-manifests'
    targetRevision: HEAD
  destination:
    server: https://kubernetes.default.svc
    namespace: default
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
EOF

  depends_on = [github_repository.argocd_apps]
}

resource "github_repository_file" "nginx_manifest" {
  repository = github_repository.argocd_apps.name
  file       = "nginx-manifests/nginx.yaml"
  content    = <<-EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx
  namespace: default
spec:
  replicas: 1
  selector:
    matchLabels:
      app: nginx
  template:
    metadata:
      labels:
        app: nginx
    spec:
      containers:
      - name: nginx
        image: nginx:1.14.2
        ports:
        - containerPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: nginx
  namespace: default
spec:
  selector:
    app: nginx
  ports:
    - protocol: TCP
      port: 80
      targetPort: 80
---
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: nginx-route
  namespace: default
spec:
  parentRefs:
  - name: default-gateway
    namespace: default
    kind: Gateway
  hostnames:
  - "test-nginx.${var.domain_name}"
  rules:
  - matches:
    - path:
        type: PathPrefix
        value: /
    backendRefs:
    - name: nginx
      port: 80
EOF

  depends_on = [github_repository.argocd_apps]
}
