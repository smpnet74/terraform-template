# Kubeflow Main Components (sync wave 1)

# Create the main Kubeflow components directory structure
# Create patches directory for ambient mesh integration
resource "github_repository_file" "kubeflow_patches_dir" {
  count      = var.enable_kubeflow ? 1 : 0
  repository = var.github_repo_name
  file       = "kubeflow/main/patches/.gitkeep"
  content    = ""
  depends_on = [var.github_repository]
}

# Create the Istio integration patch
resource "github_repository_file" "kubeflow_istio_patch" {
  count      = var.enable_kubeflow ? 1 : 0
  repository = var.github_repo_name
  file       = "kubeflow/main/patches/istio-integration.yaml"
  content    = <<-EOF
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: centraldashboard
  namespace: kubeflow
spec:
  hosts:
  - "kubeflow.${var.domain_name}"
  gateways:
  - kubeflow-gateway
EOF

  depends_on = [var.github_repository]
}

resource "github_repository_file" "kubeflow_main_kustomization" {
  count      = var.enable_kubeflow ? 1 : 0
  repository = var.github_repo_name
  file       = "kubeflow/main/kustomization.yaml"
  content    = <<-EOF
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

namespace: kubeflow

resources:
- centraldashboard.yaml
- jupyter-web-app.yaml
- notebook-controller.yaml
- profiles.yaml
- volumes-web-app.yaml
- gateway-patch.yaml
- httproute.yaml

patches:
- path: patches/istio-integration.yaml
  target:
    kind: VirtualService
    name: centraldashboard
- path: patches/ambient-mesh-patch.yaml
  target:
    kind: Namespace
    name: kubeflow
EOF

  depends_on = [
    var.github_repository,
    github_repository_file.kubeflow_patches_dir[0]
  ]
}

# Create the gateway patch for Kubeflow
resource "github_repository_file" "kubeflow_gateway_patch" {
  count      = var.enable_kubeflow ? 1 : 0
  repository = var.github_repo_name
  file       = "kubeflow/main/gateway-patch.yaml"
  content    = <<-EOF
apiVersion: networking.istio.io/v1beta1
kind: Gateway
metadata:
  name: kubeflow-gateway
  namespace: kubeflow
spec:
  selector:
    istio: ingressgateway
  servers:
  - hosts:
    - "kubeflow.${var.domain_name}"
    port:
      name: http
      number: 80
      protocol: HTTP
EOF

  depends_on = [var.github_repository]
}

# Create the ambient mesh patch for Kubeflow
resource "github_repository_file" "kubeflow_ambient_mesh_patch" {
  count      = var.enable_kubeflow ? 1 : 0
  repository = var.github_repo_name
  file       = "kubeflow/main/patches/ambient-mesh-patch.yaml"
  content    = <<-EOF
apiVersion: v1
kind: Namespace
metadata:
  name: kubeflow
  labels:
    istio.io/dataplane-mode: ambient
EOF

  depends_on = [var.github_repository]
}

# Namespace is now managed by the CRDs application (sync wave -2)

# Create the centraldashboard component
resource "github_repository_file" "kubeflow_centraldashboard" {
  count      = var.enable_kubeflow ? 1 : 0
  repository = var.github_repo_name
  file       = "kubeflow/main/centraldashboard.yaml"
  content    = <<-EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: centraldashboard
  namespace: kubeflow
spec:
  replicas: 1
  selector:
    matchLabels:
      app: centraldashboard
  template:
    metadata:
      labels:
        app: centraldashboard
    spec:
      serviceAccountName: centraldashboard
      containers:
      - name: centraldashboard
        image: docker.io/kubeflownotebookswg/centraldashboard:v1.7.0
        ports:
        - containerPort: 8082
        livenessProbe:
          httpGet:
            path: /healthz
            port: 8082
          initialDelaySeconds: 30
          periodSeconds: 30
        readinessProbe:
          httpGet:
            path: /healthz
            port: 8082
          initialDelaySeconds: 30
          periodSeconds: 30
---
apiVersion: v1
kind: Service
metadata:
  name: centraldashboard
  namespace: kubeflow
spec:
  ports:
  - port: 80
    targetPort: 8082
  selector:
    app: centraldashboard
---
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: centraldashboard
  namespace: kubeflow
spec:
  gateways:
  - kubeflow-gateway
  hosts:
  - kubeflow.timbersedgearb.com
  http:
  - match:
    - uri:
        prefix: /
    rewrite:
      uri: /
    route:
    - destination:
        host: centraldashboard.kubeflow.svc.cluster.local
        port:
          number: 8082
---
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: jupyter-web-app
  namespace: kubeflow
spec:
  gateways:
  - kubeflow-gateway
  hosts:
  - kubeflow.timbersedgearb.com
  http:
  - match:
    - uri:
        prefix: /jupyter
    rewrite:
      uri: /
    route:
    - destination:
        host: jupyter-web-app.kubeflow.svc.cluster.local
        port:
          number: 80
---
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: volumes-web-app
  namespace: kubeflow
spec:
  gateways:
  - kubeflow-gateway
  hosts:
  - kubeflow.timbersedgearb.com
  http:
  - match:
    - uri:
        prefix: /volumes
    rewrite:
      uri: /
    route:
    - destination:
        host: volumes-web-app.kubeflow.svc.cluster.local
        port:
          number: 80
---
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: profiles-kfam
  namespace: kubeflow
spec:
  hosts:
  - profiles-kfam.kubeflow.svc.cluster.local
  http:
  - route:
    - destination:
        host: profiles-kfam.kubeflow.svc.cluster.local
        port:
          number: 8081
---
# Add ServiceAccount for centraldashboard
apiVersion: v1
kind: ServiceAccount
metadata:
  name: centraldashboard
  namespace: kubeflow
---
# Add ClusterRole for centraldashboard
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: centraldashboard
rules:
- apiGroups: [""] 
  resources: ["nodes", "namespaces", "events", "configmaps"]
  verbs: ["get", "list", "watch"]
- apiGroups: ["app.k8s.io"]
  resources: ["applications"]
  verbs: ["get", "list", "watch"]
---
# Add ClusterRoleBinding for centraldashboard
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: centraldashboard
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: centraldashboard
subjects:
- kind: ServiceAccount
  name: centraldashboard
  namespace: kubeflow
---
# Add ConfigMap for centraldashboard
apiVersion: v1
kind: ConfigMap
metadata:
  name: centraldashboard-config
  namespace: kubeflow
data:
  links: |
    {
      "menuLinks": [
        {
          "link": "/jupyter/",
          "text": "Notebooks"
        },
        {
          "link": "/volumes/",
          "text": "Volumes"
        }
      ],
      "externalLinks": [],
      "quickLinks": [
        {
          "text": "Upload a pipeline",
          "desc": "Pipelines",
          "link": "/pipeline/"
        },
        {
          "text": "View all pipeline runs",
          "desc": "Pipelines",
          "link": "/pipeline/#/runs"
        },
        {
          "text": "Create a new Notebook server",
          "desc": "Notebook Servers",
          "link": "/jupyter/new?namespace=kubeflow"
        },
        {
          "text": "View Notebook servers",
          "desc": "Notebook Servers",
          "link": "/jupyter/"
        }
      ],
      "documentationItems": [
        {
          "text": "Getting Started with Kubeflow",
          "desc": "Get your machine-learning workflow up and running on Kubeflow",
          "link": "https://www.kubeflow.org/docs/started/getting-started/"
        },
        {
          "text": "MiniKF",
          "desc": "A fast and easy way to deploy Kubeflow locally",
          "link": "https://www.kubeflow.org/docs/started/getting-started-minikf/"
        },
        {
          "text": "Microk8s",
          "desc": "Quickly get Kubeflow running locally on native hypervisors",
          "link": "https://www.kubeflow.org/docs/started/getting-started-multipass/"
        },
        {
          "text": "Kubeflow on GCP",
          "desc": "Running Kubeflow on Kubernetes Engine and Google Cloud Platform",
          "link": "https://www.kubeflow.org/docs/gke/"
        },
        {
          "text": "Kubeflow on AWS",
          "desc": "Running Kubeflow on Elastic Container Service and Amazon Web Services",
          "link": "https://www.kubeflow.org/docs/aws/"
        },
        {
          "text": "Requirements for Kubeflow",
          "desc": "Get more detailed information about using Kubeflow and its components",
          "link": "https://www.kubeflow.org/docs/started/requirements/"
        }
      ]
    }
EOF

  depends_on = [var.github_repository]
}

# Create the jupyter-web-app component
resource "github_repository_file" "kubeflow_jupyter_web_app" {
  count      = var.enable_kubeflow ? 1 : 0
  repository = var.github_repo_name
  file       = "kubeflow/main/jupyter-web-app.yaml"
  content    = <<-EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: jupyter-web-app
  namespace: kubeflow
spec:
  replicas: 1
  selector:
    matchLabels:
      app: jupyter-web-app
  template:
    metadata:
      labels:
        app: jupyter-web-app
    spec:
      containers:
      - name: jupyter-web-app
        image: docker.io/kubeflownotebookswg/jupyter-web-app:v1.7.0
        ports:
        - containerPort: 5000
---
apiVersion: v1
kind: Service
metadata:
  name: jupyter-web-app
  namespace: kubeflow
spec:
  ports:
  - port: 80
    targetPort: 5000
  selector:
    app: jupyter-web-app
EOF

  depends_on = [var.github_repository]
}

# Create the notebook controller component
resource "github_repository_file" "kubeflow_notebook_controller" {
  count      = var.enable_kubeflow ? 1 : 0
  repository = var.github_repo_name
  file       = "kubeflow/main/notebook-controller.yaml"
  content    = <<-EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: notebook-controller
  namespace: kubeflow
spec:
  replicas: 1
  selector:
    matchLabels:
      app: notebook-controller
  template:
    metadata:
      labels:
        app: notebook-controller
    spec:
      serviceAccountName: notebook-controller
      containers:
      - name: notebook-controller
        image: docker.io/kubeflownotebookswg/notebook-controller:v1.7.0
        env:
        - name: USE_ISTIO
          value: "true"
        - name: CONTROLLER_NAMESPACE
          value: kubeflow
        - name: ISTIO_GATEWAY
          value: kubeflow/kubeflow-gateway
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: notebook-controller
  namespace: kubeflow
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: notebook-controller-role
rules:
- apiGroups:
  - kubeflow.org
  resources:
  - notebooks
  verbs:
  - '*'
- apiGroups:
  - ""
  resources:
  - pods
  - pods/status
  - services
  - events
  - configmaps
  - secrets
  verbs:
  - '*'
- apiGroups:
  - "apps"
  resources:
  - statefulsets
  - deployments
  verbs:
  - '*'
- apiGroups:
  - "networking.istio.io"
  resources:
  - virtualservices
  verbs:
  - '*'
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: notebook-controller-role-binding
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: notebook-controller-role
subjects:
- kind: ServiceAccount
  name: notebook-controller
  namespace: kubeflow
EOF

  depends_on = [var.github_repository]
}

# Create the profiles component
resource "github_repository_file" "kubeflow_profiles" {
  count      = var.enable_kubeflow ? 1 : 0
  repository = var.github_repo_name
  file       = "kubeflow/main/profiles.yaml"
  content    = <<-EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: profile-controller-config
  namespace: kubeflow
data:
  namespace-labels.yaml: |
    istio.io/dataplane-mode: ambient
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: profiles
  namespace: kubeflow
spec:
  replicas: 1
  selector:
    matchLabels:
      app: profiles
  template:
    metadata:
      labels:
        app: profiles
    spec:
      serviceAccountName: profiles
      containers:
      - name: profiles
        image: docker.io/kubeflownotebookswg/profile-controller:v1.7.0
        command: ["/manager"]
        volumeMounts:
        - name: profile-controller-config
          mountPath: /etc/profile-controller
      volumes:
      - name: profile-controller-config
        configMap:
          name: profile-controller-config
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: profiles
  namespace: kubeflow
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: profiles-controller-role
rules:
- apiGroups:
  - kubeflow.org
  resources:
  - profiles
  verbs:
  - '*'
- apiGroups:
  - ""
  resources:
  - namespaces
  - serviceaccounts
  - events
  - configmaps
  - secrets
  verbs:
  - '*'
- apiGroups:
  - rbac.authorization.k8s.io
  resources:
  - roles
  - rolebindings
  verbs:
  - '*'
- apiGroups:
  - security.istio.io
  resources:
  - authorizationpolicies
  verbs:
  - '*'
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: profiles-controller-role-binding
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: profiles-controller-role
subjects:
- kind: ServiceAccount
  name: profiles
  namespace: kubeflow
---
# Add profiles-kfam service for centraldashboard to connect to
apiVersion: apps/v1
kind: Deployment
metadata:
  name: profiles-kfam
  namespace: kubeflow
spec:
  replicas: 1
  selector:
    matchLabels:
      app: profiles-kfam
  template:
    metadata:
      labels:
        app: profiles-kfam
    spec:
      serviceAccountName: profiles
      containers:
      - name: kfam
        image: docker.io/kubeflownotebookswg/kfam:v1.7.0
        command: ["/access-management"]
        ports:
        - containerPort: 8081
        env:
        - name: LISTEN_PORT
          value: "8081"
---
apiVersion: v1
kind: Service
metadata:
  name: profiles-kfam
  namespace: kubeflow
spec:
  ports:
  - port: 8081
    protocol: TCP
    targetPort: 8081
  selector:
    app: profiles-kfam
---
# Add default profile for Kubeflow
apiVersion: kubeflow.org/v1
kind: Profile
metadata:
  name: kubeflow-user-example-com
spec:
  owner:
    kind: User
    name: user@example.com
EOF

  depends_on = [var.github_repository]
}

# Create the volumes-web-app component
resource "github_repository_file" "kubeflow_volumes_web_app" {
  count      = var.enable_kubeflow ? 1 : 0
  repository = var.github_repo_name
  file       = "kubeflow/main/volumes-web-app.yaml"
  content    = <<-EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: volumes-web-app
  namespace: kubeflow
spec:
  replicas: 1
  selector:
    matchLabels:
      app: volumes-web-app
  template:
    metadata:
      labels:
        app: volumes-web-app
    spec:
      containers:
      - name: volumes-web-app
        image: docker.io/kubeflownotebookswg/volumes-web-app:v1.7.0
        ports:
        - containerPort: 5000
---
apiVersion: v1
kind: Service
metadata:
  name: volumes-web-app
  namespace: kubeflow
spec:
  ports:
  - port: 80
    targetPort: 5000
  selector:
    app: volumes-web-app
EOF

  depends_on = [var.github_repository]
}

# Placeholder comment to maintain structure
# The duplicate kubeflow_istio_patch resource was removed from here

# Create HTTPRoute for Kubeflow to integrate with kgateway
resource "github_repository_file" "kubeflow_httproute" {
  count      = var.enable_kubeflow ? 1 : 0
  repository = var.github_repo_name
  file       = "kubeflow/main/httproute.yaml"
  content    = <<-EOF
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: kubeflow-route
  namespace: kubeflow
spec:
  hostnames:
  - "kubeflow.${var.domain_name}"
  parentRefs:
  - group: gateway.networking.k8s.io
    kind: Gateway
    name: default-gateway
    namespace: default
  rules:
  - backendRefs:
    - group: ""
      kind: Service
      name: istio-ingressgateway
      namespace: istio-system
      port: 80
      weight: 1
    matches:
    - path:
        type: PathPrefix
        value: /
EOF

  depends_on = [var.github_repository]
}

# ArgoCD Application for main Kubeflow components
resource "kubectl_manifest" "kubeflow_main_app" {
  count     = var.enable_kubeflow ? 1 : 0
  yaml_body = <<-EOF
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: kubeflow
  namespace: argocd
  annotations:
    argocd.argoproj.io/sync-wave: "1"
  finalizers:
    - resources-finalizer.argocd.argoproj.io
spec:
  project: default
  source:
    repoURL: ${var.github_repo_url}
    path: kubeflow/main
    targetRevision: HEAD
  destination:
    server: https://kubernetes.default.svc
    namespace: kubeflow
  dependsOn:
    - name: kubeflow-infrastructure
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
    kubectl_manifest.kubeflow_infra_app[0],
    github_repository_file.kubeflow_main_kustomization[0],
    github_repository_file.kubeflow_gateway_patch[0],
    github_repository_file.kubeflow_ambient_mesh_patch[0],
    github_repository_file.kubeflow_httproute[0],
    github_repository_file.kubeflow_centraldashboard[0],
    github_repository_file.kubeflow_jupyter_web_app[0],
    github_repository_file.kubeflow_notebook_controller[0],
    github_repository_file.kubeflow_profiles[0],
    github_repository_file.kubeflow_volumes_web_app[0],
    github_repository_file.kubeflow_istio_patch[0],
    github_repository_file.kubeflow_patches_dir[0]
  ]
}

# Add DNS record for Kubeflow
resource "kubectl_manifest" "kubeflow_dns" {
  count     = var.enable_kubeflow ? 1 : 0
  yaml_body = <<-EOF
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: kubeflow-dashboard-route
  namespace: kubeflow
spec:
  parentRefs:
  - name: default-gateway
    namespace: default
    kind: Gateway
  hostnames:
  - "kubeflow.${var.domain_name}"
  rules:
  - matches:
    - path:
        type: PathPrefix
        value: /
    backendRefs:
    - name: centraldashboard
      port: 80
      kind: Service
EOF

  depends_on = [
    kubectl_manifest.kubeflow_main_app[0]
  ]
}
