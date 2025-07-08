# Bookinfo Module - Main Configuration
# This module deploys the Bookinfo sample application with ArgoCD

# Create the ArgoCD application file for Bookinfo
resource "github_repository_file" "bookinfo_app" {
  count      = var.enable_bookinfo ? 1 : 0
  repository = var.github_repo_name
  file       = "apps/bookinfo.yaml"
  content    = <<-EOF
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: bookinfo
  namespace: argocd
spec:
  project: default
  source:
    repoURL: ${var.github_repo_url}
    path: 'bookinfo-manifests'
    targetRevision: HEAD
  destination:
    server: https://kubernetes.default.svc
    namespace: bookinfo
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
EOF
}

# Create the Bookinfo manifests file
resource "github_repository_file" "bookinfo_manifests" {
  count      = var.enable_bookinfo ? 1 : 0
  repository = var.github_repo_name
  file       = "bookinfo-manifests/bookinfo.yaml"
  content    = <<-EOF
# Kiali Bookinfo View ConfigMap
apiVersion: v1
kind: ConfigMap
metadata:
  name: kiali-bookinfo-view
  namespace: istio-system
  labels:
    app: kiali
    app.kubernetes.io/name: kiali
    app.kubernetes.io/part-of: kiali
data:
  bookinfo-view: |
    {
      "name": "bookinfo",
      "title": "Bookinfo Application",
      "description": "Bookinfo sample application with Ambient Mesh",
      "namespace": {
        "name": "bookinfo"
      },
      "graph": {
        "layout": "kiali-breadthfirst",
        "elements": {
          "nodes": [
            {
              "data": {
                "id": "ratings",
                "nodeType": "service",
                "namespace": "bookinfo",
                "service": "ratings",
                "version": "v1"
              }
            },
            {
              "data": {
                "id": "reviews",
                "nodeType": "service",
                "namespace": "bookinfo",
                "service": "reviews",
                "version": "v1,v2,v3"
              }
            },
            {
              "data": {
                "id": "details",
                "nodeType": "service",
                "namespace": "bookinfo",
                "service": "details",
                "version": "v1"
              }
            },
            {
              "data": {
                "id": "productpage",
                "nodeType": "service",
                "namespace": "bookinfo",
                "service": "productpage",
                "version": "v1"
              }
            }
          ]
        }
      }
    }
---
# Namespace for Bookinfo application
apiVersion: v1
kind: Namespace
metadata:
  name: bookinfo
  labels:
    istio-injection: enabled
---
# Bookinfo application from Istio samples
apiVersion: v1
kind: ServiceAccount
metadata:
  name: bookinfo-details
  namespace: bookinfo
---
apiVersion: v1
kind: Service
metadata:
  name: details
  namespace: bookinfo
  labels:
    app: details
    service: details
spec:
  ports:
  - port: 9080
    name: http
  selector:
    app: details
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: details-v1
  namespace: bookinfo
  labels:
    app: details
    version: v1
spec:
  replicas: 1
  selector:
    matchLabels:
      app: details
      version: v1
  template:
    metadata:
      labels:
        app: details
        version: v1
    spec:
      serviceAccountName: bookinfo-details
      containers:
      - name: details
        image: docker.io/istio/examples-bookinfo-details-v1:1.18.0
        imagePullPolicy: IfNotPresent
        ports:
        - containerPort: 9080
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: bookinfo-ratings
  namespace: bookinfo
---
apiVersion: v1
kind: Service
metadata:
  name: ratings
  namespace: bookinfo
  labels:
    app: ratings
    service: ratings
spec:
  ports:
  - port: 9080
    name: http
  selector:
    app: ratings
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ratings-v1
  namespace: bookinfo
  labels:
    app: ratings
    version: v1
spec:
  replicas: 1
  selector:
    matchLabels:
      app: ratings
      version: v1
  template:
    metadata:
      labels:
        app: ratings
        version: v1
    spec:
      serviceAccountName: bookinfo-ratings
      containers:
      - name: ratings
        image: docker.io/istio/examples-bookinfo-ratings-v1:1.18.0
        imagePullPolicy: IfNotPresent
        ports:
        - containerPort: 9080
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: bookinfo-reviews
  namespace: bookinfo
---
apiVersion: v1
kind: Service
metadata:
  name: reviews
  namespace: bookinfo
  labels:
    app: reviews
    service: reviews
spec:
  ports:
  - port: 9080
    name: http
  selector:
    app: reviews
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: reviews-v1
  namespace: bookinfo
  labels:
    app: reviews
    version: v1
spec:
  replicas: 1
  selector:
    matchLabels:
      app: reviews
      version: v1
  template:
    metadata:
      labels:
        app: reviews
        version: v1
    spec:
      serviceAccountName: bookinfo-reviews
      containers:
      - name: reviews
        image: docker.io/istio/examples-bookinfo-reviews-v1:1.18.0
        imagePullPolicy: IfNotPresent
        env:
        - name: LOG_DIR
          value: "/tmp/logs"
        ports:
        - containerPort: 9080
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: reviews-v2
  namespace: bookinfo
  labels:
    app: reviews
    version: v2
spec:
  replicas: 1
  selector:
    matchLabels:
      app: reviews
      version: v2
  template:
    metadata:
      labels:
        app: reviews
        version: v2
    spec:
      serviceAccountName: bookinfo-reviews
      containers:
      - name: reviews
        image: docker.io/istio/examples-bookinfo-reviews-v2:1.18.0
        imagePullPolicy: IfNotPresent
        env:
        - name: LOG_DIR
          value: "/tmp/logs"
        ports:
        - containerPort: 9080
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: reviews-v3
  namespace: bookinfo
  labels:
    app: reviews
    version: v3
spec:
  replicas: 1
  selector:
    matchLabels:
      app: reviews
      version: v3
  template:
    metadata:
      labels:
        app: reviews
        version: v3
    spec:
      serviceAccountName: bookinfo-reviews
      containers:
      - name: reviews
        image: docker.io/istio/examples-bookinfo-reviews-v3:1.18.0
        imagePullPolicy: IfNotPresent
        env:
        - name: LOG_DIR
          value: "/tmp/logs"
        ports:
        - containerPort: 9080
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: bookinfo-productpage
  namespace: bookinfo
---
apiVersion: v1
kind: Service
metadata:
  name: productpage
  namespace: bookinfo
  labels:
    app: productpage
    service: productpage
spec:
  ports:
  - port: 9080
    name: http
  selector:
    app: productpage
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: productpage-v1
  namespace: bookinfo
  labels:
    app: productpage
    version: v1
spec:
  replicas: 1
  selector:
    matchLabels:
      app: productpage
      version: v1
  template:
    metadata:
      labels:
        app: productpage
        version: v1
    spec:
      serviceAccountName: bookinfo-productpage
      containers:
      - name: productpage
        image: docker.io/istio/examples-bookinfo-productpage-v1:1.18.0
        imagePullPolicy: IfNotPresent
        ports:
        - containerPort: 9080
EOF
}

# Create the HTTPRoute for Bookinfo to expose via KGateway
resource "github_repository_file" "bookinfo_httproute" {
  count      = var.enable_bookinfo ? 1 : 0
  repository = var.github_repo_name
  file       = "bookinfo-manifests/bookinfo-httproute.yaml"
  content    = <<-EOF
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: bookinfo-route
  namespace: bookinfo
spec:
  parentRefs:
  - name: default-gateway
    namespace: default
    kind: Gateway
    group: gateway.networking.k8s.io
  hostnames:
  - "bookinfo.${var.domain_name}"
  rules:
  - matches:
    - path:
        type: PathPrefix
        value: /
    backendRefs:
    - name: productpage
      port: 9080
EOF
}

# Bookinfo Application in ArgoCD
resource "kubectl_manifest" "bookinfo_app" {
  count     = var.enable_bookinfo ? 1 : 0
  yaml_body = <<-EOF
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: bookinfo
  namespace: argocd
spec:
  project: default
  source:
    repoURL: ${var.github_repo_url}
    path: 'bookinfo-manifests'
    targetRevision: HEAD
  destination:
    server: https://kubernetes.default.svc
    namespace: bookinfo
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
EOF

  depends_on = [
    var.argocd_helm_release,
    github_repository_file.bookinfo_manifests,
    github_repository_file.bookinfo_httproute,
  ]
}
