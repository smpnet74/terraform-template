# AgentGateway Standalone Configuration
# Provides MCP protocol support independent of kgateway version

# Namespace for AgentGateway deployment
resource "kubectl_manifest" "agentgateway_namespace" {
  yaml_body = <<-YAML
apiVersion: v1
kind: Namespace
metadata:
  name: ai-gateway-system
  labels:
    app.kubernetes.io/name: agentgateway
    app.kubernetes.io/component: namespace
    app.kubernetes.io/managed-by: terraform
YAML
}

# ConfigMap for AgentGateway configuration
resource "kubectl_manifest" "agentgateway_config" {
  yaml_body = <<-YAML
apiVersion: v1
kind: ConfigMap
metadata:
  name: agentgateway-config
  namespace: ai-gateway-system
  labels:
    app.kubernetes.io/name: agentgateway
    app.kubernetes.io/component: config
    app.kubernetes.io/managed-by: terraform
data:
  config.yaml: |
    # AgentGateway configuration for MCP protocols
    binds:
    - port: 8080
      listeners:
      - routes:
        - policies:
            cors:
              allowOrigins:
                - "*"
              allowHeaders:
                - "mcp-protocol-version"
                - "content-type"
                - "*"
              allowMethods:
                - "GET"
                - "POST" 
                - "PUT"
                - "DELETE"
                - "OPTIONS"
          backends:
          - mcp:
              name: "mcp-everything"
              targets:
              - name: "everything"
                stdio:
                  cmd: "npx"
                  args: ["@modelcontextprotocol/server-everything"]
YAML

  depends_on = [
    kubectl_manifest.agentgateway_namespace
  ]
}

# Service Account for AgentGateway
resource "kubectl_manifest" "agentgateway_service_account" {
  yaml_body = <<-YAML
apiVersion: v1
kind: ServiceAccount
metadata:
  name: agentgateway
  namespace: ai-gateway-system
  labels:
    app.kubernetes.io/name: agentgateway
    app.kubernetes.io/component: service-account
    app.kubernetes.io/managed-by: terraform
YAML

  depends_on = [
    kubectl_manifest.agentgateway_namespace
  ]
}

# ClusterRole for AgentGateway (needed for A2A service discovery)
resource "kubectl_manifest" "agentgateway_cluster_role" {
  yaml_body = <<-YAML
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: agentgateway
  labels:
    app.kubernetes.io/name: agentgateway
    app.kubernetes.io/component: rbac
    app.kubernetes.io/managed-by: terraform
rules:
- apiGroups: [""]
  resources: ["services", "endpoints"]
  verbs: ["get", "list", "watch"]
- apiGroups: [""]
  resources: ["pods"]
  verbs: ["get", "list", "watch"]
- apiGroups: ["apps"]
  resources: ["deployments"]
  verbs: ["get", "list", "watch"]
YAML
}

# ClusterRoleBinding for AgentGateway
resource "kubectl_manifest" "agentgateway_cluster_role_binding" {
  yaml_body = <<-YAML
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: agentgateway
  labels:
    app.kubernetes.io/name: agentgateway
    app.kubernetes.io/component: rbac
    app.kubernetes.io/managed-by: terraform
subjects:
- kind: ServiceAccount
  name: agentgateway
  namespace: ai-gateway-system
roleRef:
  kind: ClusterRole
  name: agentgateway
  apiGroup: rbac.authorization.k8s.io
YAML

  depends_on = [
    kubectl_manifest.agentgateway_service_account,
    kubectl_manifest.agentgateway_cluster_role
  ]
}

# AgentGateway Deployment
resource "kubectl_manifest" "agentgateway_deployment" {
  yaml_body = <<-YAML
apiVersion: apps/v1
kind: Deployment
metadata:
  name: agentgateway
  namespace: ai-gateway-system
  labels:
    app.kubernetes.io/name: agentgateway
    app.kubernetes.io/component: deployment
    app.kubernetes.io/managed-by: terraform
spec:
  replicas: 1
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1
      maxUnavailable: 0
  selector:
    matchLabels:
      app.kubernetes.io/name: agentgateway
      app.kubernetes.io/component: gateway
  template:
    metadata:
      labels:
        app.kubernetes.io/name: agentgateway
        app.kubernetes.io/component: gateway
      annotations:
        checksum/config: "config-updated"
    spec:
      serviceAccountName: agentgateway
      securityContext:
        runAsNonRoot: true
        runAsUser: 1000
        fsGroup: 1000
      containers:
      - name: agentgateway
        image: ghcr.io/agentgateway/agentgateway:0.6.2
        imagePullPolicy: IfNotPresent
        args: ["--file=/etc/agentgateway/config.yaml"]
        ports:
        - name: mcp
          containerPort: 8080
          protocol: TCP
        - name: http
          containerPort: 3000
          protocol: TCP
        - name: ui
          containerPort: 15000
          protocol: TCP
        - name: metrics
          containerPort: 9090
          protocol: TCP
        env:
        - name: RUST_LOG
          value: "info"
        - name: AGENTGATEWAY_CONFIG
          value: "/etc/agentgateway/config.yaml"
        - name: ADMIN_ADDR
          value: "0.0.0.0:15000"
        - name: AGENTGATEWAY_ADMIN_ADDR
          value: "0.0.0.0:15000"
        volumeMounts:
        - name: config
          mountPath: /etc/agentgateway
          readOnly: true
        resources:
          requests:
            cpu: "100m"
            memory: "128Mi"
          limits:
            cpu: "500m"
            memory: "512Mi"
        livenessProbe:
          httpGet:
            path: /healthz/ready
            port: 15021
          initialDelaySeconds: 30
          periodSeconds: 10
          timeoutSeconds: 5
          failureThreshold: 3
        readinessProbe:
          httpGet:
            path: /healthz/ready
            port: 15021
          initialDelaySeconds: 5
          periodSeconds: 5
          timeoutSeconds: 3
          failureThreshold: 3
        securityContext:
          runAsNonRoot: true
          runAsUser: 1000
          capabilities:
            drop:
            - ALL
          readOnlyRootFilesystem: false
      volumes:
      - name: config
        configMap:
          name: agentgateway-config
YAML

  depends_on = [
    kubectl_manifest.agentgateway_config,
    kubectl_manifest.agentgateway_service_account,
    kubectl_manifest.agentgateway_cluster_role_binding
  ]
}

# Service for AgentGateway
resource "kubectl_manifest" "agentgateway_service" {
  yaml_body = <<-YAML
apiVersion: v1
kind: Service
metadata:
  name: agentgateway
  namespace: ai-gateway-system
  labels:
    app.kubernetes.io/name: agentgateway
    app.kubernetes.io/component: service
    app.kubernetes.io/managed-by: terraform
  annotations:
    prometheus.io/scrape: "true"
    prometheus.io/port: "9090"
    prometheus.io/path: "/metrics"
spec:
  type: ClusterIP
  ports:
  - name: mcp
    port: 8080
    targetPort: mcp
    protocol: TCP
  - name: http
    port: 3000
    targetPort: http
    protocol: TCP
  - name: ui
    port: 15000
    targetPort: ui
    protocol: TCP
  - name: metrics
    port: 9090
    targetPort: metrics
    protocol: TCP
  selector:
    app.kubernetes.io/name: agentgateway
    app.kubernetes.io/component: gateway
YAML

  depends_on = [
    kubectl_manifest.agentgateway_deployment
  ]
}

# HTTPRoute for AgentGateway UI access via existing default-gateway
resource "kubectl_manifest" "agentgateway_httproute" {
  yaml_body = <<-YAML
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: agentgateway-ui
  namespace: ai-gateway-system
  labels:
    app.kubernetes.io/name: agentgateway
    app.kubernetes.io/component: httproute
    app.kubernetes.io/managed-by: terraform
spec:
  parentRefs:
  - name: default-gateway
    namespace: default
  hostnames:
  - "agentgateway.${var.domain_name}"
  rules:
  - matches:
    - path:
        type: PathPrefix
        value: "/"
    backendRefs:
    - name: agentgateway
      port: 15000
      weight: 100
---
apiVersion: gateway.networking.k8s.io/v1beta1
kind: ReferenceGrant
metadata:
  name: agentgateway-grant
  namespace: ai-gateway-system
  labels:
    app.kubernetes.io/name: agentgateway
    app.kubernetes.io/component: reference-grant
    app.kubernetes.io/managed-by: terraform
spec:
  from:
  - group: gateway.networking.k8s.io
    kind: HTTPRoute
    namespace: default
  to:
  - group: ""
    kind: Service
    name: agentgateway
YAML

  depends_on = [
    kubectl_manifest.agentgateway_service,
    kubectl_manifest.default_gateway
  ]
}

# ServiceMonitor for Prometheus monitoring
resource "kubectl_manifest" "agentgateway_servicemonitor" {
  count = var.enable_prometheus_operator ? 1 : 0
  
  yaml_body = <<-YAML
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: agentgateway
  namespace: ai-gateway-system
  labels:
    app.kubernetes.io/name: agentgateway
    app.kubernetes.io/component: monitoring
    app.kubernetes.io/managed-by: terraform
    # Labels for kube-prometheus-stack discovery
    release: kube-prometheus-stack
spec:
  selector:
    matchLabels:
      app.kubernetes.io/name: agentgateway
      app.kubernetes.io/component: service
  endpoints:
  - port: metrics
    path: /metrics
    interval: 30s
    scrapeTimeout: 10s
YAML

  depends_on = [
    kubectl_manifest.agentgateway_service
  ]
}