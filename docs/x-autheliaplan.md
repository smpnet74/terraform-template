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

## Implementation Plan (Revised)

This revised plan incorporates lessons learned from the ZenML deployment, focusing on automation, security, and modularity. It replaces insecure defaults with automated secret generation and ensures a robust, GitOps-aligned deployment.

### Phase 1: Create `authelia.tf`

All Authelia-related resources will be encapsulated in a new `authelia.tf` file.

```hcl
# authelia.tf

# 1. Create a dedicated namespace for Authelia
resource "kubernetes_namespace" "authelia" {
  count = var.enable_authelia ? 1 : 0
  metadata {
    name = var.authelia_namespace
    labels = {
      "app.kubernetes.io/name"    = "authelia"
      "istio.io/dataplane-mode" = "ambient"
    }
  }
}

# 2. Generate all necessary secrets dynamically
resource "random_password" "authelia_jwt_secret" {
  count   = var.enable_authelia ? 1 : 0
  length  = 64
  special = false
}

resource "random_password" "authelia_session_secret" {
  count   = var.enable_authelia ? 1 : 0
  length  = 64
  special = false
}

resource "random_password" "authelia_storage_encryption_key" {
  count   = var.enable_authelia ? 1 : 0
  length  = 64
  special = false
}

resource "random_password" "authelia_postgres_password" {
  count   = var.enable_authelia ? 1 : 0
  length  = 24
  special = false
}

resource "random_password" "authelia_redis_password" {
  count   = var.enable_authelia ? 1 : 0
  length  = 24
  special = false
}

resource "random_password" "authelia_admin_password" {
  count   = var.enable_authelia ? 1 : 0
  length  = 24
  special = false
}

# Hash the admin password using bcrypt (required by Authelia)
resource "bcrypt_hash" "authelia_admin_password_hash" {
  count      = var.enable_authelia ? 1 : 0
  cleartext  = random_password.authelia_admin_password[0].result
  cost       = 12
}

# 3. Create secrets for the database passwords
resource "kubernetes_secret" "authelia_postgres_creds" {
  count = var.enable_authelia ? 1 : 0
  metadata {
    name      = "authelia-postgres-auth"
    namespace = var.authelia_namespace
  }
  data = {
    "password" = random_password.authelia_postgres_password[0].result
    "username" = "authelia"
  }
}

resource "kubernetes_secret" "authelia_redis_creds" {
  count = var.enable_authelia ? 1 : 0
  metadata {
    name      = "authelia-redis-auth"
    namespace = var.authelia_namespace
  }
  data = {
    "password" = random_password.authelia_redis_password[0].result
  }
}

# 4. Provision backend databases using KubeBlocks
resource "kubectl_manifest" "authelia_postgres_cluster" {
  count      = var.enable_authelia ? 1 : 0
  yaml_body  = <<-YAML
apiVersion: apps.kubeblocks.io/v1
kind: Cluster
metadata:
  name: authelia-postgres
  namespace: ${var.authelia_namespace}
spec:
  clusterDefinitionRef: postgresql
  clusterVersionRef: postgresql-16.2.0
  componentSpecs:
  - name: postgresql
    componentDefRef: postgresql
    replicas: 1
    # This tells KubeBlocks to use the secret we created for the initial user/password.
    # The user 'authelia' will be created with the password from the secret.
    userPasswordSecret:
      name: ${kubernetes_secret.authelia_postgres_creds[0].metadata[0].name}
    resources:
      requests:
        cpu: 100m
        memory: 256Mi
    storage:
      name: data
      storageClassName: civo-volume
      size: 5Gi
  terminationPolicy: WipeOut
YAML
  depends_on = [helm_release.kubeblocks, kubernetes_namespace.authelia, kubernetes_secret.authelia_postgres_creds]
}

resource "kubectl_manifest" "authelia_redis_cluster" {
  count      = var.enable_authelia ? 1 : 0
  yaml_body  = <<-YAML
apiVersion: apps.kubeblocks.io/v1
kind: Cluster
metadata:
  name: authelia-redis
  namespace: ${var.authelia_namespace}
spec:
  clusterDefinitionRef: redis
  clusterVersionRef: redis-7.2.4
  componentSpecs:
  - name: redis
    componentDefRef: redis
    replicas: 1
    # Use the generated password for the Redis instance
    userPasswordSecret:
      name: ${kubernetes_secret.authelia_redis_creds[0].metadata[0].name}
    resources:
      requests:
        cpu: 100m
        memory: 256Mi
    storage:
      name: data
      storageClassName: civo-volume
      size: 2Gi
  terminationPolicy: WipeOut
YAML
  depends_on = [helm_release.kubeblocks, kubernetes_namespace.authelia, kubernetes_secret.authelia_redis_creds]
}

# 5. Create the main Authelia configuration as a Kubernetes secret
# This includes templating the generated secrets and user credentials.
resource "kubernetes_secret" "authelia_config" {
  count = var.enable_authelia ? 1 : 0
  metadata {
    name      = "authelia-config"
    namespace = var.authelia_namespace
  }

  data = {
    "users_database.yml" = yamlencode({
      users = {
        "admin" = {
          displayname = "Administrator"
          # Use bcrypt-hashed password as required by Authelia
          password    = bcrypt_hash.authelia_admin_password_hash[0].hash
          email       = "admin@${var.domain_name}"
          groups      = ["admins", "dev"]
        }
      }
    })

    "configuration.yml" = yamlencode({
      theme = "auto"
      jwt_secret = random_password.authelia_jwt_secret[0].result
      default_redirection_url = "https://auth.${var.domain_name}"

      server = {
        host = "0.0.0.0"
        port = 9091
        path = ""
        enable_pprof = false
        enable_expvars = false
        disable_healthcheck = false
      }

      log = {
        level = "info"
        format = "text"
        keep_stdout = true
      }

      totp = {
        issuer = var.domain_name
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
        secret = random_password.authelia_session_secret[0].result
        expiration = "12h"
        inactivity = "45m"
        remember_me_duration = "1M"
        redis = {
          host = "authelia-redis-redis.${var.authelia_namespace}.svc.cluster.local"
          port = 6379
          password = kubernetes_secret.authelia_redis_creds[0].data.password
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

      storage = {
        encryption_key = random_password.authelia_storage_encryption_key[0].result
        postgres = {
          host = "authelia-postgres-postgresql.${var.authelia_namespace}.svc.cluster.local"
          port = 5432
          database = "authelia"
          schema = "public"
          username = kubernetes_secret.authelia_postgres_creds[0].data.username
          password = kubernetes_secret.authelia_postgres_creds[0].data.password
          timeout = "5s"
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
  depends_on = [kubectl_manifest.authelia_redis_cluster, kubectl_manifest.authelia_postgres_cluster]
}

# 6. Deploy Authelia using the official Helm chart
resource "helm_release" "authelia" {
  count      = var.enable_authelia ? 1 : 0
  name       = "authelia"
  repository = "https://charts.authelia.com"
  chart      = "authelia"
  version    = var.authelia_chart_version
  namespace  = var.authelia_namespace

  values = [
    yamlencode({
      image = {
        registry = "ghcr.io"
        repository = "authelia/authelia"
        tag = "4.38.8"
      }
      
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
        enabled = false
      }
      
      secret = {
        existingSecret = kubernetes_secret.authelia_config[0].metadata[0].name
        subPath = "configuration.yml"
        additionalSecrets = [
          {
            name = kubernetes_secret.authelia_config[0].metadata[0].name
            subPath = "users_database.yml"
          }
        ]
      }
      
      service = {
        type = "ClusterIP"
        port = 80
        targetPort = 9091
      }
      
      ingress = {
        enabled = false
      }
      
      persistence = {
        enabled = true
        storageClass = ""
        accessMode = "ReadWriteOnce"
        size = "1Gi"
      }
    })
  ]
  depends_on = [kubernetes_secret.authelia_config, kubectl_manifest.authelia_redis_cluster, kubectl_manifest.authelia_postgres_cluster]
}

# 7. Create Gateway API HTTPRoute for the Authelia portal
resource "kubectl_manifest" "httproute_authelia" {
  count      = var.enable_authelia ? 1 : 0
  yaml_body  = <<-YAML
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: authelia
  namespace: ${var.authelia_namespace}
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
      port: 9091
      kind: Service
YAML
  depends_on = [helm_release.authelia, kubectl_manifest.default_gateway]
}

# 8. Create ReferenceGrant to allow cross-namespace routing
resource "kubectl_manifest" "refgrant_authelia" {
  count      = var.enable_authelia ? 1 : 0
  yaml_body  = <<-YAML
apiVersion: gateway.networking.k8s.io/v1beta1
kind: ReferenceGrant
metadata:
  name: authelia-access
  namespace: ${var.authelia_namespace}
spec:
  from:
  - group: gateway.networking.k8s.io
    kind: HTTPRoute
    namespace: ${var.authelia_namespace}
  to:
  - group: ""
    kind: Service
    name: authelia
YAML
}

# 9. Create SecurityPolicy to protect Grafana
resource "kubectl_manifest" "secpolicy_grafana" {
  count      = var.enable_authelia && var.enable_grafana ? 1 : 0
  yaml_body  = <<-YAML
apiVersion: gateway.networking.k8s.io/v1alpha2
kind: SecurityPolicy
metadata:
  name: grafana-auth
  namespace: ${var.monitoring_namespace}
spec:
  targetRef:
    group: gateway.networking.k8s.io
    kind: HTTPRoute
    name: grafana-http
  extAuth:
    http:
      serviceRef:
        name: authelia
        namespace: ${var.authelia_namespace}
        port: 9091
      path: /api/authz/forward-auth
YAML
  depends_on = [helm_release.authelia, helm_release.grafana]
}

# 10. Create ServiceMonitor for Prometheus
resource "kubectl_manifest" "authelia_servicemonitor" {
  count = var.enable_authelia && var.enable_prometheus_operator ? 1 : 0
  yaml_body = <<-YAML
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: authelia
  namespace: ${var.monitoring_namespace}
  labels:
    release: kube-prometheus-stack
spec:
  selector:
    matchLabels:
      app.kubernetes.io/name: authelia
  namespaceSelector:
    matchNames:
    - ${var.authelia_namespace}
  endpoints:
  - port: http
    path: /api/metrics
    interval: 30s
YAML
  depends_on = [helm_release.authelia]
}

# 11. Update Kyverno policies to exclude authelia-system namespace
resource "kubectl_manifest" "kyverno_authelia_exclusion" {
  count = var.enable_authelia && var.enable_kyverno ? 1 : 0
  yaml_body = <<-YAML
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: require-resource-requests-updated
  annotations:
    policies.kyverno.io/title: Require Resource Requests (Updated for Authelia)
    policies.kyverno.io/category: Best Practices
    policies.kyverno.io/severity: medium
    policies.kyverno.io/subject: Pod
spec:
  validationFailureAction: enforce
  background: true
  rules:
  - name: check-container-resources
    match:
      any:
      - resources:
          kinds:
          - Pod
    exclude:
      any:
      - resources:
          namespaces: 
          - kube-system
          - kyverno
          - kgateway-system
          - local-path-storage
          - istio-system
          - monitoring
          - policy-reporter
          - ${var.authelia_namespace}  # Add Authelia namespace exclusion
      - resources:
          selector:
            matchLabels:
              workload-type: debug
      - resources:
          selector:
            matchLabels:
              workload-type: temporary
    validate:
      message: "Production containers should specify CPU and memory requests."
      anyPattern:
      - spec:
          containers:
          - resources:
              requests:
                cpu: "?*"
                memory: "?*"
      - metadata:
          annotations:
            policy.kyverno.io/exempt-resource-requests: "true"
YAML
  depends_on = [helm_release.kyverno]
}
```

### Phase 2: Add Required Provider and Update Variables

**Add bcrypt provider to `provider.tf`:**

```hcl
terraform {
  required_providers {
    # ... existing providers ...
    bcrypt = {
      source  = "viktorradnai/bcrypt"
      version = "~> 0.1.2"
    }
  }
}

provider "bcrypt" {}
```

**Add new variables to `io.tf`:**

```hcl
# Authelia Authentication
variable "enable_authelia" {
  description = "Whether to deploy the Authelia authentication system"
  type        = bool
  default     = false
}

variable "authelia_chart_version" {
  description = "Version of the Authelia Helm chart"
  type        = string
  default     = "0.9.3"
}

variable "authelia_namespace" {
  description = "Namespace for Authelia components"
  type        = string
  default     = "authelia-system"
}
```

**Add new outputs to `outputs.tf`:**

```hcl
# outputs.tf

output "authelia_portal_url" {
  description = "URL for the Authelia login portal."
  value       = var.enable_authelia ? "https://auth.${var.domain_name}" : "Authelia is disabled."
}

output "authelia_initial_admin_password" {
  description = "The generated initial password for the 'admin' user. Use this to log in for the first time."
  value       = var.enable_authelia ? random_password.authelia_admin_password[0].result : "Authelia is disabled."
  sensitive   = true
}
```

### Phase 3: Pre-Deployment Verification

**IMPORTANT: Verify SecurityPolicy API Version**
Before deploying, verify that Kgateway supports the SecurityPolicy API version used in the plan:

```bash
kubectl api-resources | grep securitypolicy
kubectl api-versions | grep gateway
```

If `gateway.networking.k8s.io/v1alpha2` is not available, update the SecurityPolicy resources to use the correct API version supported by your Kgateway installation.

### Phase 4: Deployment & Documentation

1.  **Enable Authelia:** Set `enable_authelia = true` in `terraform.tfvars`.
2.  **Apply Changes:** Run `terraform apply`.
3.  **Check Outputs:** Note the `authelia_portal_url` and the sensitive `authelia_initial_admin_password`.
4.  **Test Login:** Access a protected service (e.g., Grafana). You should be redirected to the Authelia portal. Log in with username `admin` and the generated password.
5.  **Update Documentation:** After successful testing, update `versions.md`, `terraform_files_documentation.md`, and `order_of_execution.md`.

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