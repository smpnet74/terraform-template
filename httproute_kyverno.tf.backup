# Policy Reporter UI - Web-based dashboard for Kyverno policy management and compliance reporting
# https://kyverno.github.io/policy-reporter/

# Policy Reporter WITHOUT Prometheus Operator (basic setup)
resource "helm_release" "policy_reporter_basic" {
  count      = var.enable_kyverno && var.enable_policy_reporter_ui && !var.enable_prometheus_operator ? 1 : 0
  name       = "policy-reporter"
  repository = "https://kyverno.github.io/policy-reporter"
  chart      = "policy-reporter"
  version    = var.policy_reporter_chart_version
  namespace  = "policy-reporter"
  create_namespace = true
  
  values = [
    yamlencode({
      # UI Configuration
      ui = {
        enabled = true
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
      
      # Core Policy Reporter Configuration
      policyReporter = {
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
      
      # Kyverno Plugin - Essential for policy management
      kyvernoPlugin = {
        enabled = true
      }
      
      # Monitoring disabled (no Prometheus Operator)
      monitoring = {
        enabled = false
      }
      
      # Enable basic metrics endpoint
      metrics = {
        enabled = true
        port = 2112
      }
      
      # Database configuration (SQLite for simplicity)
      database = {
        type = "sqlite"
      }
    })
  ]
  
  depends_on = [
    helm_release.kyverno,
    null_resource.verify_kyverno_webhooks
  ]
}

# Policy Reporter WITH Prometheus Operator (full monitoring setup)
resource "helm_release" "policy_reporter_full" {
  count      = var.enable_kyverno && var.enable_policy_reporter_ui && var.enable_prometheus_operator ? 1 : 0
  name       = "policy-reporter"
  repository = "https://kyverno.github.io/policy-reporter"
  chart      = "policy-reporter"
  version    = var.policy_reporter_chart_version
  namespace  = "policy-reporter"
  create_namespace = true
  
  values = [
    yamlencode({
      # UI Configuration
      ui = {
        enabled = true
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
      
      # Core Policy Reporter Configuration
      policyReporter = {
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
      
      # Kyverno Plugin - Essential for policy management
      kyvernoPlugin = {
        enabled = true
      }
      
      # Monitoring enabled (with Prometheus Operator)
      monitoring = {
        enabled = true  # ServiceMonitor will be created
      }
      
      # Enable basic metrics endpoint
      metrics = {
        enabled = true
        port = 2112
      }
      
      # Database configuration (SQLite for simplicity)
      database = {
        type = "sqlite"
      }
    })
  ]
  
  depends_on = [
    helm_release.kyverno,
    null_resource.verify_kyverno_webhooks,
    time_sleep.wait_for_prometheus_operator  # Wait for Prometheus Operator to be fully ready
  ]
}

# ReferenceGrant to allow HTTPRoute in default namespace to access Policy Reporter UI service
resource "kubectl_manifest" "policy_reporter_reference_grant" {
  count = var.enable_kyverno && var.enable_policy_reporter_ui ? 1 : 0
  yaml_body = <<-YAML
apiVersion: gateway.networking.k8s.io/v1beta1
kind: ReferenceGrant
metadata:
  name: policy-reporter-access
  namespace: policy-reporter
spec:
  from:
  - group: gateway.networking.k8s.io
    kind: HTTPRoute
    namespace: default
  to:
  - group: ""
    kind: Service
    name: policy-reporter-ui
YAML

  depends_on = [
    helm_release.policy_reporter_basic,
    helm_release.policy_reporter_full
  ]
}

# HTTPRoute for Policy Reporter UI access via Gateway API
resource "kubectl_manifest" "policy_reporter_httproute" {
  count = var.enable_kyverno && var.enable_policy_reporter_ui ? 1 : 0
  yaml_body = <<-YAML
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: policy-reporter-ui
  namespace: default
  annotations:
    kyverno.io/policy-exempt: "true"  # Exempt from our own HTTPRoute validation
spec:
  parentRefs:
  - name: default-gateway
    namespace: default
    kind: Gateway
  hostnames:
  - "policy-reporter.${var.domain_name}"
  rules:
  - matches:
    - path:
        type: PathPrefix
        value: "/"
    backendRefs:
    - name: policy-reporter-ui
      namespace: policy-reporter
      port: 8080
      kind: Service
YAML

  depends_on = [
    helm_release.policy_reporter_basic,
    helm_release.policy_reporter_full,
    kubectl_manifest.policy_reporter_reference_grant,
    kubectl_manifest.default_gateway
  ]
}