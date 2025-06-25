provider "github" {
  token = var.github_token
}

resource "github_repository" "argocd_apps" {
  name        = var.github_repo_name
  description = "Kubernetes application configurations managed by Argo CD"
  visibility  = "public"
}

resource "github_repository_file" "longhorn_app" {
  repository = github_repository.argocd_apps.name
  file       = "apps/longhorn.yaml"
  content    = <<-EOF
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: longhorn
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://charts.longhorn.io
    chart: longhorn
    targetRevision: 1.8.2
  destination:
    server: https://kubernetes.default.svc
    namespace: longhorn-system
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
    - CreateNamespace=true
EOF

  depends_on = [github_repository.argocd_apps]
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
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: nginx-ingress
  namespace: default
  annotations:
    kubernetes.io/ingress.class: traefik
spec:
  rules:
  - host: nginx.${var.domain_name}
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: nginx
            port:
              number: 80
EOF

  depends_on = [github_repository.argocd_apps]
}
