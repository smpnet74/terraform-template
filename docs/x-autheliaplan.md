# Authelia Authentication Implementation Plan

## Overview

This document outlines a comprehensive plan to implement Authelia cloud-native authentication in the Kubernetes cluster to secure internal tools including Policy Reporter, Kiali, Grafana, and Argo Workflows. The implementation leverages Gateway API SecurityPolicy integration while maintaining compatibility with existing Kyverno policies and monitoring infrastructure.

## Current Security Gap

The cluster currently exposes several internal tools without authentication:
- **Policy Reporter UI**: `https://policy-reporter.timbersedgearb.com` (Kyverno policy management)
- **Kiali Dashboard**: `https://kiali.timbersedgearb.com` (Istio service mesh observability)
- **Grafana Dashboards**: `https://grafana.timbersedgearb.com` (Monitoring and metrics)
- **Argo Workflows UI**: `https://argo-workflows.timbersedgearb.com` (Workflow management)

These tools contain sensitive cluster information and administrative capabilities that require proper authentication and authorization.

## Solution Architecture

### Authelia Cloud-Native Authentication

Authelia provides:
- **Forward Authentication**: Integrates with reverse proxies and ingress controllers
- **Multi-Factor Authentication**: TOTP/2FA support for enhanced security
- **Session Management**: Redis-backed session storage with configurable timeouts
- **User Management**: File-based, LDAP, or OIDC identity providers
- **Gateway API Integration**: Native support for Kubernetes Gateway API SecurityPolicy

### Architecture Components

```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   User Browser  │────│  Gateway API     │────│  Internal Tool  │
│                 │    │  + SecurityPolicy│    │  (Policy Rep.)  │
└─────────────────┘    └──────────────────┘    └─────────────────┘
                               │
                               ▼
                       ┌──────────────────┐    ┌─────────────────┐
                       │    Authelia      │────│   KubeBlocks    │
                       │   (Auth Portal)  │    │ Redis Cluster   │
                       └──────────────────┘    └─────────────────┘
                                              ┌─────────────────┐
                                              │   KubeBlocks    │
                                              │PostgreSQL Cluster│
                                              │ (Optional Storage)│
                                              └─────────────────┘
```

## Implementation Plan

### Phase 1: Infrastructure Foundation

#### 1.1 Add Configuration Variables (`io.tf`)

```hcl
# Authelia Authentication Configuration
variable "enable_authelia" {
  description = "Whether to deploy Authelia authentication system"
  type        = bool
  default     = true
}

variable "authelia_chart_version" {
  description = "Version of the Authelia Helm chart"
  type        = string
  default     = "0.9.3"  # Latest stable version
}

variable "authelia_namespace" {
  description = "Namespace for Authelia components"
  type        = string
  default     = "authelia-system"
}

variable "authelia_session_secret" {
  description = "Secret key for Authelia session encryption (32+ chars)"
  type        = string
  sensitive   = true
  default     = "insecure_session_secret_change_me_in_production"
}

variable "authelia_jwt_secret" {
  description = "Secret key for Authelia JWT tokens (32+ chars)"
  type        = string
  sensitive   = true
  default     = "insecure_jwt_secret_change_me_in_production"
}

variable "authelia_storage_secret" {
  description = "Secret key for Authelia storage encryption (32+ chars)"
  type        = string
  sensitive   = true
  default     = "insecure_storage_secret_change_me_in_production"
}

variable "authelia_users" {
  description = "List of Authelia users with passwords (bcrypt hashed)"
  type = list(object({
    username    = string
    displayname = string
    password    = string  # bcrypt hash
    email       = string
    groups      = list(string)
  }))
  default = [
    {
      username    = "admin"
      displayname = "Administrator"
      password    = "$2a$14$jmcHqHMcsrbwpTmO8HO7Nu.pQyT7mfx2jUYvmvI3k.Y8uJd0YE1M2"  # "password"
      email       = "admin@timbersedgearb.com"
      groups      = ["admins", "dev"]
    }
  ]
  sensitive = true
}

variable "authelia_redis_password" {
  description = "Password for Redis session storage"
  type        = string
  sensitive   = true
  default     = "change_me_redis_password_in_production"
}

variable "authelia_storage_type" {
  description = "Storage backend type for Authelia (sqlite or postgres)"
  type        = string
  default     = "postgres"
  validation {
    condition     = contains(["sqlite", "postgres"], var.authelia_storage_type)
    error_message = "Storage type must be either 'sqlite' or 'postgres'."
  }
}

variable "authelia_postgres_password" {
  description = "Password for PostgreSQL database (when using postgres storage)"
  type        = string
  sensitive   = true
  default     = "change_me_postgres_password_in_production"
}
```

#### 1.2 Create Database Infrastructure with KubeBlocks

```hcl
# KubeBlocks Redis Cluster for Authelia session storage
resource "kubectl_manifest" "authelia_redis_cluster" {
  count = var.enable_authelia ? 1 : 0
  yaml_body = <<-YAML
apiVersion: v1
kind: ServiceAccount
metadata:
  name: kb-psa-authelia-redis
  namespace: ${var.authelia_namespace}
---
apiVersion: apps.kubeblocks.io/v1
kind: Cluster
metadata:
  name: authelia-redis
  namespace: ${var.authelia_namespace}
  labels:
    app.kubernetes.io/name: authelia-redis
    app.kubernetes.io/part-of: authelia
spec:
  clusterDef: redis
  terminationPolicy: Halt  # Preserve data for session storage
  componentSpecs:
    - name: redis
      componentDef: redis
      replicas: 1  # Single instance for session storage
      serviceAccountName: kb-psa-authelia-redis
      resources:
        limits:
          cpu: 200m
          memory: 256Mi
        requests:
          cpu: 50m
          memory: 128Mi
      volumeClaimTemplates:
        - name: data
          spec:
            accessModes:
              - ReadWriteOnce
            resources:
              requests:
                storage: 2Gi  # Sufficient for session storage
YAML

  depends_on = [
    helm_release.kubeblocks,
    kubernetes_namespace.authelia_namespace
  ]
}

# KubeBlocks PostgreSQL Cluster for Authelia data storage (optional)
resource "kubectl_manifest" "authelia_postgres_cluster" {
  count = var.enable_authelia && var.authelia_storage_type == "postgres" ? 1 : 0
  yaml_body = <<-YAML
apiVersion: v1
kind: ServiceAccount
metadata:
  name: kb-psa-authelia-postgres
  namespace: ${var.authelia_namespace}
---
apiVersion: apps.kubeblocks.io/v1
kind: Cluster
metadata:
  name: authelia-postgres
  namespace: ${var.authelia_namespace}
  labels:
    app.kubernetes.io/name: authelia-postgres
    app.kubernetes.io/part-of: authelia
spec:
  clusterDef: postgresql
  terminationPolicy: Halt  # Preserve authentication data
  componentSpecs:
    - name: postgresql
      componentDef: postgresql
      replicas: 1  # Single instance for authentication storage
      serviceAccountName: kb-psa-authelia-postgres
      resources:
        limits:
          cpu: 200m
          memory: 256Mi
        requests:
          cpu: 100m
          memory: 256Mi
      volumeClaimTemplates:
        - name: data
          spec:
            accessModes:
              - ReadWriteOnce
            resources:
              requests:
                storage: 5Gi  # Authentication data storage
YAML

  depends_on = [
    helm_release.kubeblocks,
    kubernetes_namespace.authelia_namespace
  ]
}

# Wait for database clusters to be ready
resource "time_sleep" "wait_for_authelia_databases" {
  count = var.enable_authelia ? 1 : 0
  depends_on = [
    kubectl_manifest.authelia_redis_cluster,
    kubectl_manifest.authelia_postgres_cluster
  ]
  create_duration = "120s"  # KubeBlocks clusters need time to initialize
}

# Create namespace for Authelia
resource "kubernetes_namespace" "authelia_namespace" {
  count = var.enable_authelia ? 1 : 0
  metadata {
    name = var.authelia_namespace
    labels = {
      "app.kubernetes.io/name" = "authelia"
      "app.kubernetes.io/part-of" = "authelia"
    }
  }
}

# Authelia configuration secret
resource "kubernetes_secret" "authelia_config" {
  count = var.enable_authelia ? 1 : 0
  metadata {
    name      = "authelia-config"
    namespace = var.authelia_namespace
  }
  
  data = {
    "users_database.yml" = yamlencode({
      users = {
        for user in var.authelia_users : user.username => {
          displayname = user.displayname
          password    = user.password
          email       = user.email
          groups      = user.groups
        }
      }
    })
    
    "configuration.yml" = yamlencode({
      theme = "auto"
      jwt_secret = var.authelia_jwt_secret
      default_redirection_url = "https://policy-reporter.${var.domain_name}"
      
      server = {
        host = "0.0.0.0"
        port = 9091
        path = ""
        enable_pprof = false
        enable_expvars = false
        disable_healthcheck = false
        tls = {
          key = ""
          certificate = ""
        }
      }
      
      log = {
        level = "info"
        format = "text"
        file_path = ""
        keep_stdout = true
      }
      
      totp = {
        issuer = "timbersedgearb.com"
        period = 30
        skew = 1
      }
      
      authentication_backend = {
        file = {
          path = "/config/users_database.yml"
          password = {
            algorithm = "argon2id"
            iterations = 1
            salt_length = 16
            parallelism = 8
            memory = 64
          }
        }
      }
      
      access_control = {
        default_policy = "deny"
        rules = [
          {
            domain = "policy-reporter.${var.domain_name}"
            policy = "two_factor"
            subject = ["group:admins", "group:dev"]
          },
          {
            domain = "kiali.${var.domain_name}"
            policy = "two_factor"
            subject = ["group:admins"]
          },
          {
            domain = "grafana.${var.domain_name}"
            policy = "one_factor"
            subject = ["group:admins", "group:dev"]
          },
          {
            domain = "argo-workflows.${var.domain_name}"
            policy = "two_factor"
            subject = ["group:admins"]
          }
        ]
      }
      
      session = {
        name = "authelia_session"
        secret = var.authelia_session_secret
        expiration = "12h"
        inactivity = "45m"
        remember_me_duration = "1M"
        
        redis = {
          host = "authelia-redis-redis.${var.authelia_namespace}.svc.cluster.local"
          port = 6379
          password = var.authelia_redis_password
          database_index = 0
          maximum_active_connections = 8
          minimum_idle_connections = 0
        }
      }
      
      regulation = {
        max_retries = 3
        find_time = "2m"
        ban_time = "5m"
      }
      
      storage = var.authelia_storage_type == "postgres" ? {
        encryption_key = var.authelia_storage_secret
        postgres = {
          host = "authelia-postgres-postgresql.${var.authelia_namespace}.svc.cluster.local"
          port = 5432
          database = "authelia"
          schema = "public"
          username = "postgres"
          password = var.authelia_postgres_password
          timeout = "5s"
        }
      } : {
        encryption_key = var.authelia_storage_secret
        local = {
          path = "/config/db.sqlite3"
        }
      }
      
      notifier = {
        disable_startup_check = true
        filesystem = {
          filename = "/config/notification.txt"
        }
      }
    })
  }
  
  depends_on = [
    kubectl_manifest.authelia_redis_cluster,
    kubernetes_namespace.authelia_namespace
  ]
}

# Authelia main deployment
resource "helm_release" "authelia" {
  count      = var.enable_authelia ? 1 : 0
  name       = "authelia"
  repository = "https://charts.authelia.com"
  chart      = "authelia"
  version    = var.authelia_chart_version
  namespace  = var.authelia_namespace
  create_namespace = true
  
  values = [
    yamlencode({
      domain = var.domain_name
      
      pod = {
        kind = "Deployment"
        replicas = 1
        
        resources = {
          limits = {
            cpu    = "200m"
            memory = "256Mi"
          }
          requests = {
            cpu    = "50m"
            memory = "128Mi"
          }
        }
        
        securityContext = {
          runAsNonRoot = true
          runAsUser    = 1000
          fsGroup      = 1000
        }
      }
      
      configMap = {
        enabled = false  # Using manual secret
      }
      
      secret = {
        existingSecret = "authelia-config"
      }
      
      service = {
        type = "ClusterIP"
        port = 80
        targetPort = 9091
      }
      
      ingress = {
        enabled = false  # Using Gateway API
      }
      
      persistence = {
        enabled = true
        storageClass = ""
        accessMode = "ReadWriteOnce"
        size = "1Gi"
      }
    })
  ]
  
  depends_on = [
    kubernetes_secret.authelia_config,
    time_sleep.wait_for_authelia_databases
  ]
}
```

### Phase 2: Kyverno Policy Updates

#### 2.1 Update Policy Exclusions (`kyverno_custom_policies.tf`)

```hcl
# Update resource requirements policy to exclude authelia-system
resource "kubectl_manifest" "kyverno_resource_requirements" {
  count = var.enable_kyverno ? 1 : 0
  yaml_body = <<-YAML
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: require-resource-requests
spec:
  # ... existing configuration ...
  rules:
  - name: check-container-resources
    exclude:
      any:
      # Exclude system namespaces (updated)
      - resources:
          namespaces: 
          - kube-system
          - kyverno
          - kgateway-system
          - local-path-storage
          - istio-system
          - monitoring
          - policy-reporter
          - authelia-system  # Add authelia exclusion
      # ... rest of existing configuration ...
YAML
}
```

#### 2.2 Create Authelia-Specific Policies

```hcl
# Authelia Configuration Validation Policy
resource "kubectl_manifest" "kyverno_authelia_config_policy" {
  count = var.enable_kyverno && var.enable_authelia ? 1 : 0
  yaml_body = <<-YAML
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: authelia-configuration-standards
  annotations:
    policies.kyverno.io/title: Authelia Configuration Standards
    policies.kyverno.io/category: Security
    policies.kyverno.io/severity: high
    policies.kyverno.io/subject: Secret
    policies.kyverno.io/description: >-
      Ensures Authelia configuration secrets follow security best practices
      including proper secret rotation and encryption key management.
spec:
  validationFailureAction: enforce
  background: true
  rules:
  - name: validate-authelia-secrets
    match:
      any:
      - resources:
          kinds:
          - Secret
          namespaces:
          - authelia-system
          names:
          - "authelia-*"
    validate:
      message: "Authelia secrets must be properly formatted"
      pattern:
        type: "Opaque"
        data:
          "configuration.yml": "?*"
YAML
}
```

### Phase 3: Gateway API SecurityPolicy Integration

#### 3.1 Create Authelia HTTPRoute

```hcl
# Authelia authentication portal HTTPRoute
resource "kubectl_manifest" "authelia_httproute" {
  count = var.enable_authelia ? 1 : 0
  yaml_body = <<-YAML
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: authelia-portal
  namespace: default
  annotations:
    kyverno.io/policy-exempt: "true"
spec:
  parentRefs:
  - name: default-gateway
    namespace: default
    kind: Gateway
  hostnames:
  - "auth.${var.domain_name}"
  rules:
  - matches:
    - path:
        type: PathPrefix
        value: "/"
    backendRefs:
    - name: authelia
      namespace: ${var.authelia_namespace}
      port: 80
      kind: Service
YAML
  
  depends_on = [
    helm_release.authelia,
    kubectl_manifest.default_gateway
  ]
}

# ReferenceGrant for Authelia service access
resource "kubectl_manifest" "authelia_reference_grant" {
  count = var.enable_authelia ? 1 : 0
  yaml_body = <<-YAML
apiVersion: gateway.networking.k8s.io/v1beta1
kind: ReferenceGrant
metadata:
  name: authelia-access
  namespace: ${var.authelia_namespace}
spec:
  from:
  - group: gateway.networking.k8s.io
    kind: HTTPRoute
    namespace: default
  to:
  - group: ""
    kind: Service
    name: authelia
YAML
  
  depends_on = [
    helm_release.authelia
  ]
}
```

#### 3.2 Create SecurityPolicy for Policy Reporter

```hcl
# SecurityPolicy for Policy Reporter authentication
resource "kubectl_manifest" "policy_reporter_security_policy" {
  count = var.enable_authelia && var.enable_policy_reporter_ui ? 1 : 0
  yaml_body = <<-YAML
apiVersion: gateway.envoyproxy.io/v1alpha1
kind: SecurityPolicy
metadata:
  name: policy-reporter-auth
  namespace: default
spec:
  targetRef:
    group: gateway.networking.k8s.io
    kind: HTTPRoute
    name: policy-reporter-ui
  extAuth:
    http:
      headersToBackend:
      - "Remote-User"
      - "Remote-Groups"
      - "Remote-Name"
      - "Remote-Email"
      service:
        name: authelia
        namespace: ${var.authelia_namespace}
        port: 80
      path: "/api/authz/forward-auth"
      headersToAdd:
      - name: "X-Forwarded-Proto"
        value: "https"
      - name: "X-Forwarded-Host"
        value: "policy-reporter.${var.domain_name}"
      - name: "X-Forwarded-Uri"
        value: "/"
YAML
  
  depends_on = [
    helm_release.authelia,
    kubectl_manifest.policy_reporter_httproute
  ]
}
```

### Phase 4: Monitoring Integration

#### 4.1 Add ServiceMonitor for Authelia

```hcl
# ServiceMonitor for Authelia metrics (when Prometheus Operator is enabled)
resource "kubectl_manifest" "authelia_servicemonitor" {
  count = var.enable_authelia && var.enable_prometheus_operator ? 1 : 0
  yaml_body = <<-YAML
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: authelia
  namespace: ${var.authelia_namespace}
  labels:
    app.kubernetes.io/name: authelia
spec:
  selector:
    matchLabels:
      app.kubernetes.io/name: authelia
  endpoints:
  - port: http
    path: /metrics
    interval: 30s
    scrapeTimeout: 10s
YAML
  
  depends_on = [
    helm_release.authelia,
    time_sleep.wait_for_prometheus_operator
  ]
}
```

### Phase 5: Tool-Specific Extensions

#### 5.1 Grafana Authentication Headers

```hcl
# Update Grafana configuration for auth proxy headers
# Add to helm_grafana.tf values:
set {
  name  = "grafana.ini.auth\\.proxy.enabled"
  value = var.enable_authelia ? "true" : "false"
}

set {
  name  = "grafana.ini.auth\\.proxy.header_name"
  value = "Remote-User"
}

set {
  name  = "grafana.ini.auth\\.proxy.header_property"
  value = "username"
}

set {
  name  = "grafana.ini.auth\\.proxy.auto_sign_up"
  value = var.enable_authelia ? "true" : "false"
}
```

#### 5.2 Kiali Authentication Integration

```hcl
# Update Kiali configuration for external authentication
# Add to helm_kiali.tf values:
set {
  name  = "auth.strategy"
  value = var.enable_authelia ? "header" : "anonymous"
}

set {
  name  = "auth.header"
  value = var.enable_authelia ? "Remote-User" : ""
}
```

## Security Considerations

### Secret Management
- All sensitive data stored in Kubernetes secrets
- Secrets encrypted at rest with cluster encryption
- Rotation strategy for session, JWT, and storage keys
- Bcrypt password hashing for user credentials

### Access Control
- Two-factor authentication required for sensitive tools
- Role-based access with user groups
- Session timeout and inactivity controls
- Failed authentication attempt regulation

### Network Security
- TLS termination at Gateway with Cloudflare certificates
- Encrypted communication between components
- Redis session storage with authentication
- No direct external access to Authelia components

## Deployment Dependencies

### Required Order
1. **KubeBlocks Operator**: Must be deployed and ready
2. **Kyverno Policy Updates**: Exclude authelia-system namespace
3. **Database Deployment**: KubeBlocks Redis and PostgreSQL clusters
4. **Authelia Configuration**: Secrets and configuration with database connections
5. **Authelia Service**: Main authentication service
6. **Gateway Configuration**: HTTPRoute and SecurityPolicy
7. **Tool Integration**: Update existing HTTPRoutes

### Compatibility Requirements
- **KubeBlocks v1.0+**: Database operator for Redis and PostgreSQL
- **Gateway API v1.2+**: SecurityPolicy support
- **Kgateway v2.0+**: SecurityPolicy CRDs
- **Prometheus Operator**: Monitoring integration
- **Cloudflare certificates**: Existing infrastructure

## Testing Strategy

### Authentication Flow Validation
1. Access Policy Reporter without authentication (should redirect)
2. Login through Authelia portal with valid credentials
3. Verify successful redirection to Policy Reporter
4. Test session persistence across browser sessions
5. Validate logout and session cleanup

### Security Testing
1. Invalid credential rejection
2. Brute force protection activation
3. Session timeout enforcement
4. 2FA requirement for sensitive tools
5. Cross-site request forgery protection

## Migration Path

### Phase 1: Foundation (Day 1)
- Deploy KubeBlocks database clusters (Redis + PostgreSQL)
- Update Kyverno policies for namespace exclusions
- Deploy Authelia infrastructure with database connections
- Create authentication portal HTTPRoute

### Phase 2: Secure Policy Reporter (Day 2)
- Implement SecurityPolicy for Policy Reporter
- Test authentication flow with KubeBlocks databases
- Validate session management and data persistence

### Phase 3: Extend to Other Tools (Week 1)
- Secure Grafana with authentication headers
- Implement Kiali authentication
- Add Argo Workflows protection

### Phase 4: Enhanced Security (Week 2)
- Enable 2FA for all users
- Implement LDAP/OIDC integration
- Add audit logging and monitoring

## Maintenance Considerations

### Regular Tasks
- Monitor authentication metrics and failures
- Review and rotate encryption keys quarterly
- Update user access and group memberships
- Backup Authelia configuration and user database

### Troubleshooting
- **Authelia service logs**: `kubectl logs -n authelia-system -l app.kubernetes.io/name=authelia`
- **KubeBlocks Redis cluster**: `kubectl get cluster authelia-redis -n authelia-system`
- **KubeBlocks PostgreSQL cluster**: `kubectl get cluster authelia-postgres -n authelia-system`
- **Redis connection test**: `kubectl exec -n authelia-system -it authelia-redis-redis-0 -- redis-cli ping`
- **PostgreSQL connection test**: `kubectl exec -n authelia-system -it authelia-postgres-postgresql-0 -- psql -U postgres -d authelia -c "SELECT 1;"`
- **Gateway API validation**: `kubectl describe securitypolicy policy-reporter-auth`
- **Session debugging**: Check KubeBlocks Redis for active sessions

## Extension Opportunities

### Advanced Features
- **LDAP Integration**: Connect to existing directory services
- **OIDC Provider**: Integration with external identity providers
- **Custom Rules**: Advanced access control with time-based restrictions
- **Audit Logging**: Enhanced security event tracking
- **Mobile 2FA**: Push notification support

### Additional Tools
- **ArgoCD UI**: If deployed externally
- **Prometheus UI**: Direct access protection
- **Alertmanager**: Alert management security
- **Custom Applications**: Extend authentication to deployed apps

This comprehensive plan provides enterprise-grade authentication for the cluster while maintaining compatibility with existing infrastructure and following cloud-native best practices.