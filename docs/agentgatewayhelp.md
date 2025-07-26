# AgentGateway Deployment Guide

This document provides a comprehensive reference for deploying AgentGateway as a standalone service in our Kubernetes cluster for MCP (Model Context Protocol) support.

## Overview

AgentGateway is a high-performance Rust-based gateway that provides MCP and A2A (Agent-to-Agent) communication protocols. In our deployment, it runs as a standalone service completely independent of kgateway.

## Architecture

```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   Client Apps   │───▶│  AgentGateway    │───▶│  MCP Servers    │
│   (port 8080)   │    │  (port 8080)     │    │  (stdio)        │
└─────────────────┘    └──────────────────┘    └─────────────────┘
                                │
                                ▼
┌─────────────────┐    ┌──────────────────┐
│ External Users  │───▶│   Gateway API    │
│ (UI Access)     │    │   (HTTPRoute)    │
└─────────────────┘    └──────────────────┘
```

### Key Components

1. **AgentGateway Pod**: Rust application serving MCP protocol
2. **ClusterIP Service**: Internal access on port 8080 (MCP), 3000 (HTTP), 9090 (metrics)
3. **HTTPRoute**: External UI access via existing default-gateway
4. **ConfigMap**: AgentGateway configuration in proper `binds` format
5. **RBAC**: ServiceAccount, ClusterRole, ClusterRoleBinding for A2A discovery

## Critical Configuration Requirements

### 1. Configuration Format

AgentGateway requires a specific `binds` configuration format, NOT flat YAML:

```yaml
# ✅ CORRECT - binds format
binds:
- port: 8080
  listeners:
  - routes:
    - policies:
        cors:
          allowOrigins: ["*"]
          allowHeaders: ["mcp-protocol-version", "content-type", "*"]
          allowMethods: ["GET", "POST", "PUT", "DELETE", "OPTIONS"]
      backends:
      - mcp:
          name: "mcp-everything"
          targets:
          - name: "everything"
            stdio:
              cmd: "npx"
              args: ["@modelcontextprotocol/server-everything"]

# ❌ INCORRECT - flat format (causes "expected struct NestedRawConfig" error)
server:
  bind: "0.0.0.0:8080"
mcp:
  enabled: true
  backends: [...]
```

### 2. Container Arguments

AgentGateway expects `--file` argument, not `--config`:

```yaml
# ✅ CORRECT
args: ["--file=/etc/agentgateway/config.yaml"]

# ❌ INCORRECT (causes "invalid type: string" error)
args: ["--config=/etc/agentgateway/config.yaml"]
```

### 3. Docker Image Tag

Use tag without `v` prefix:

```yaml
# ✅ CORRECT
image: ghcr.io/agentgateway/agentgateway:0.6.2

# ❌ INCORRECT (causes ImagePullBackOff)
image: ghcr.io/agentgateway/agentgateway:v0.6.2
```

### 4. Health Probes

AgentGateway provides readiness endpoint on port 15021, not on the MCP port:

```yaml
# ✅ CORRECT
livenessProbe:
  httpGet:
    path: /healthz/ready
    port: 15021
readinessProbe:
  httpGet:
    path: /healthz/ready
    port: 15021

# ❌ INCORRECT (causes health probe failures)
readinessProbe:
  httpGet:
    path: /health
    port: 8080
```

## Complete Working Terraform Configuration

### File: `kgateway_agentgateway.tf`

```hcl
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
        - name: metrics
          containerPort: 9090
          protocol: TCP
        env:
        - name: RUST_LOG
          value: "info"
        - name: AGENTGATEWAY_CONFIG
          value: "/etc/agentgateway/config.yaml"
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
      port: 3000
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
```

## Deployment Process

### 1. Add Configuration File
```bash
# Create the kgateway_agentgateway.tf file with the configuration above
```

### 2. Deploy with Terraform
```bash
terraform plan
terraform apply
```

### 3. Verify Deployment
```bash
# Check pod status
kubectl --kubeconfig=kubeconfig get pods -n ai-gateway-system
# Should show: agentgateway-xxx   1/1     Running

# Check service
kubectl --kubeconfig=kubeconfig get svc -n ai-gateway-system agentgateway

# Check HTTPRoute
kubectl --kubeconfig=kubeconfig get httproute -n ai-gateway-system agentgateway-ui
```

## Testing AgentGateway

### Internal MCP Access (from within cluster)
```bash
# Port forward for testing
kubectl --kubeconfig=kubeconfig port-forward -n ai-gateway-system svc/agentgateway 8080:8080

# Test MCP endpoint
curl -X POST http://localhost:8080/mcp \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc": "2.0", "id": 1, "method": "tools/list", "params": {}}'
```

### External UI Access
```bash
# Should be available at:
# https://agentgateway.yourdomain.com
```

### Health Check
```bash
# Port forward readiness endpoint
kubectl --kubeconfig=kubeconfig port-forward -n ai-gateway-system svc/agentgateway 15021:15021

# Check health
curl http://localhost:15021/healthz/ready
```

## Common Issues and Solutions

### 1. Pod CrashLoopBackOff with "expected struct NestedRawConfig"
**Cause**: Incorrect configuration format
**Solution**: Use `binds` format instead of flat YAML structure

### 2. Pod CrashLoopBackOff with "invalid type: string"  
**Cause**: Wrong CLI argument
**Solution**: Use `--file=` instead of `--config=`

### 3. ImagePullBackOff
**Cause**: Wrong image tag with `v` prefix
**Solution**: Use `0.6.2` instead of `v0.6.2`

### 4. Pod Running but Not Ready
**Cause**: Health probes failing on wrong port
**Solution**: Use port 15021 with `/healthz/ready` path

### 5. MCP Protocol Returns 406 Not Acceptable
**Cause**: This is expected behavior - MCP endpoint returns 406 for non-MCP requests
**Solution**: Use proper MCP JSON-RPC format in requests

## Logs and Troubleshooting

### AgentGateway Logs
```bash
# View logs
kubectl --kubeconfig=kubeconfig logs -n ai-gateway-system -l app.kubernetes.io/name=agentgateway

# Follow logs in real-time
kubectl --kubeconfig=kubeconfig logs -n ai-gateway-system -l app.kubernetes.io/name=agentgateway -f
```

### Expected Log Messages
```
info agentgateway version: version.BuildInfo{...}
info state_manager Watching config file: /etc/agentgateway/config.yaml
info state_manager loaded config from File("/etc/agentgateway/config.yaml")
info agent_core::readiness marking server ready
info proxy::gateway started bind bind="bind/8080"
```

## Integration with Existing Infrastructure

### Dependencies
- **Gateway API**: HTTPRoute uses existing `default-gateway`
- **Prometheus**: ServiceMonitor integrates with `kube-prometheus-stack`
- **Kyverno**: Resource requests/limits comply with security policies

### Resource Requirements
- **CPU**: 100m request, 500m limit per replica
- **Memory**: 128Mi request, 512Mi limit per replica
- **Storage**: No persistent storage required (stateless)

### Ports
- **8080**: MCP protocol endpoint
- **3000**: HTTP/UI endpoint  
- **9090**: Prometheus metrics
- **15021**: Health/readiness endpoint

## Advanced Configuration

### Adding Additional MCP Backends
```yaml
backends:
- mcp:
    name: "mcp-everything"
    targets:
    - name: "everything"
      stdio:
        cmd: "npx"
        args: ["@modelcontextprotocol/server-everything"]
- mcp:
    name: "mcp-filesystem"
    targets:
    - name: "filesystem"
      stdio:
        cmd: "npx"
        args: ["@modelcontextprotocol/server-filesystem", "/tmp"]
```

### Scaling
```yaml
# In deployment spec
replicas: 3

# Add HPA
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: agentgateway
  namespace: ai-gateway-system
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: agentgateway
  minReplicas: 1
  maxReplicas: 5
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70
```

## Cleanup

To remove AgentGateway deployment:
```bash
# Delete namespace (removes all resources)
kubectl --kubeconfig=kubeconfig delete namespace ai-gateway-system

# Or remove via Terraform
# Comment out or delete the kgateway_agentgateway.tf file
terraform apply
```

## Compatibility Notes

- **Kgateway Version**: Works with any kgateway version (2.0.3, 2.1.0-main, etc.)
- **Kubernetes**: Requires Gateway API CRDs
- **Node Requirements**: No special node requirements
- **External Dependencies**: Requires `npx` and Node.js in container for MCP servers

## Management UI Configuration

### Critical UI Setup Requirements

The AgentGateway management UI provides configuration management, MCP playground, and real-time updates. Getting it accessible externally requires specific configuration:

#### 1. Admin Interface Binding Issue
**Problem**: By default, AgentGateway binds the admin UI to `127.0.0.1:15000` (localhost only), making it inaccessible via Kubernetes Service.

**Solution**: Use environment variables to bind to all interfaces:
```yaml
env:
- name: ADMIN_ADDR
  value: "0.0.0.0:15000"
- name: AGENTGATEWAY_ADMIN_ADDR  # Fallback option
  value: "0.0.0.0:15000"
```

#### 2. Port Configuration Requirements
The complete port setup needed:
```yaml
# Deployment container ports
ports:
- name: mcp
  containerPort: 8080          # MCP protocol endpoint
- name: http  
  containerPort: 3000          # Agent proxy connections
- name: ui
  containerPort: 15000         # Management UI (CRITICAL!)
- name: metrics
  containerPort: 9090          # Prometheus metrics

# Service ports  
ports:
- name: mcp
  port: 8080
  targetPort: mcp
- name: http
  port: 3000  
  targetPort: http
- name: ui                     # REQUIRED for external UI access
  port: 15000
  targetPort: ui
- name: metrics
  port: 9090
  targetPort: metrics
```

#### 3. HTTPRoute Configuration
**Critical**: Route to port 15000 (not 3000) for UI access:
```yaml
backendRefs:
- name: agentgateway
  port: 15000                  # Management UI port
  weight: 100
```

### UI Deployment Process

#### Step 1: Complete Port Exposure
Ensure AgentGateway deployment exposes port 15000:
- Add `containerPort: 15000` to deployment
- Add corresponding service port mapping
- Update HTTPRoute to target port 15000

#### Step 2: Admin Interface Binding
Add environment variables to make admin UI accessible:
```yaml
env:
- name: RUST_LOG
  value: "info"
- name: AGENTGATEWAY_CONFIG
  value: "/etc/agentgateway/config.yaml"
- name: ADMIN_ADDR              # CRITICAL for external access
  value: "0.0.0.0:15000"
- name: AGENTGATEWAY_ADMIN_ADDR # Backup option
  value: "0.0.0.0:15000"
```

#### Step 3: Deployment and Verification
```bash
# Apply configuration
terraform apply

# Force pod restart to pick up config changes
kubectl --kubeconfig=kubeconfig rollout restart deployment/agentgateway -n ai-gateway-system

# Verify logs show correct binding
kubectl --kubeconfig=kubeconfig logs -n ai-gateway-system -l app.kubernetes.io/name=agentgateway --tail=10

# Should see: address=0.0.0.0:15000 component="admin"
# NOT: address=127.0.0.1:15000 component="admin"
```

### UI Features Available

Once accessible, the management UI provides:
- **Configuration Management**: Create/modify backend targets without restarts
- **MCP Server Playground**: Interactive testing of MCP protocol endpoints  
- **Real-time Configuration**: Dynamic updates without pod restarts
- **Backend Status Monitoring**: Health and status of MCP connections
- **CORS Policy Management**: Configure cross-origin access policies

### Common UI Access Issues

#### Issue 1: "upstream connect error" 
**Cause**: Admin UI still bound to localhost (127.0.0.1:15000)
**Solution**: Verify environment variables are set and pod restarted

#### Issue 2: HTTPRoute 503 errors
**Cause**: HTTPRoute pointing to wrong port (often port 3000 instead of 15000)
**Solution**: Update HTTPRoute backendRefs to target port 15000

#### Issue 3: Service not exposing UI port
**Cause**: Service missing port 15000 configuration
**Solution**: Add UI port to service port list

#### Issue 4: Pod not restarting after config changes
**Cause**: Kubernetes doesn't auto-restart on ConfigMap changes
**Solution**: Manual rollout restart required: `kubectl rollout restart deployment/agentgateway`

## Port Architecture Summary

Understanding AgentGateway's port architecture is critical:

- **Port 8080**: MCP protocol endpoint (agent connections for MCP)
- **Port 3000**: HTTP proxy port (agent connections for HTTP APIs) 
- **Port 15000**: Management UI (web interface for configuration)
- **Port 15020**: Statistics endpoint (metrics and stats)
- **Port 15021**: Health/readiness endpoint (Kubernetes probes)
- **Port 9090**: Prometheus metrics (monitoring integration)

**Key Insight**: Port 3000 is NOT a UI port - it's for agent proxy connections. The actual UI runs on port 15000.

## Environment Variable Configuration

AgentGateway supports configuration via environment variables for system-level settings:

### Admin Interface Control
- `ADMIN_ADDR`: Controls admin UI binding address
- `AGENTGATEWAY_ADMIN_ADDR`: Alternative admin address variable

### Application Settings  
- `RUST_LOG`: Logging level control
- `AGENTGATEWAY_CONFIG`: Configuration file path

### Discovery and Networking
- Pod networking and DNS resolution handled automatically
- No special network configuration required beyond port exposure

## Configuration Validation

### Valid Configuration Patterns
```yaml
# VALID - MCP backend configuration
binds:
- port: 8080
  listeners:
  - routes:
    - backends:
      - mcp:
          name: "mcp-everything"
          targets:
          - name: "everything"
            stdio:
              cmd: "npx"
              args: ["@modelcontextprotocol/server-everything"]
```

### Invalid Configuration Patterns
```yaml
# INVALID - No "ui" backend type exists
backends:
- ui:
    enabled: true

# INVALID - No "static" backend type exists  
backends:
- static:
    path: "/app/ui"

# INVALID - No top-level adminAddr field
adminAddr: "0.0.0.0:15000"
```

### Error Messages and Solutions

#### "no variant of enum LocalBackend found"
**Cause**: Using invalid backend type (`ui`, `static`, etc.)
**Valid Types**: `mcp`, `a2a`, `openapi` only
**Solution**: Use only supported backend types

#### "unknown field `adminAddr`"
**Cause**: Invalid top-level YAML configuration field
**Solution**: Use environment variables for admin binding, not YAML config

#### "upstream connect error or disconnect/reset"
**Cause**: Service routing to wrong port or admin interface not bound to external interface
**Solution**: Verify port 15000 exposure and environment variable configuration

## Critical Success Factors

For successful AgentGateway UI deployment:

1. **Environment Variables**: `ADMIN_ADDR=0.0.0.0:15000` is REQUIRED
2. **Port 15000 Exposure**: Must be in both deployment and service
3. **HTTPRoute Target**: Must point to port 15000, not 3000
4. **Pod Restart**: Required after configuration changes
5. **Valid Backend Types**: Only use `mcp`, `a2a`, `openapi` in configuration

## Key Lessons Learned

1. **AgentGateway is completely independent** - doesn't require specific kgateway versions
2. **Configuration format is critical** - must use `binds` structure
3. **Health probes must use port 15021** - not the application port
4. **Image tags don't use `v` prefix** - use semantic version only
5. **CLI args use `--file`** - not `--config`
6. **MCP returns 406 for non-MCP requests** - this is normal behavior
7. **Standalone deployment is simpler** - avoid kgateway AI extension complexity
8. **Admin UI requires environment variable binding** - YAML config insufficient
9. **Port 15000 is for UI, port 3000 is for agent proxy** - don't confuse these
10. **Manual pod restart required** - after ConfigMap changes
11. **Only specific backend types are valid** - `ui` and `static` don't exist
12. **External UI access needs careful port configuration** - all three layers must align

## Complete Working Configuration Reference

For future deployments, the critical components that must be present:

### Deployment Environment Variables
```yaml
env:
- name: RUST_LOG
  value: "info"
- name: AGENTGATEWAY_CONFIG  
  value: "/etc/agentgateway/config.yaml"
- name: ADMIN_ADDR
  value: "0.0.0.0:15000"      # CRITICAL for UI access
```

### Complete Port Configuration
```yaml
# Deployment
ports:
- name: mcp
  containerPort: 8080
- name: http
  containerPort: 3000  
- name: ui
  containerPort: 15000        # REQUIRED for UI
- name: metrics
  containerPort: 9090

# Service  
ports:
- name: ui
  port: 15000                 # REQUIRED for external access
  targetPort: ui

# HTTPRoute
backendRefs:
- name: agentgateway
  port: 15000                 # CRITICAL - UI port, not 3000
```

### Deployment Commands
```bash
# Apply configuration
terraform apply

# ALWAYS restart after config changes
kubectl rollout restart deployment/agentgateway -n ai-gateway-system

# Verify correct binding in logs
kubectl logs -n ai-gateway-system -l app.kubernetes.io/name=agentgateway | grep admin
# Should show: address=0.0.0.0:15000 component="admin"
```

This comprehensive configuration ensures AgentGateway UI is accessible externally while maintaining all MCP protocol functionality.