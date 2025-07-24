# Kyverno Policy Engine Feature Module
# Deploys Kyverno, pre-built policies, custom policies, and Policy Reporter UI

# 1. Deploy Kyverno Policy Engine using Helm chart
resource "helm_release" "kyverno" {
  count      = var.enable_kyverno ? 1 : 0
  name       = "kyverno"
  repository = "https://kyverno.github.io/kyverno/"
  chart      = "kyverno"
  version    = var.kyverno_chart_version
  namespace  = "kyverno"
  create_namespace = true

  # High availability configuration for production
  values = [
    yamlencode({
      # Admission Controller Configuration
      admissionController = {
        replicas = 3
        resources = {
          limits = {
            cpu    = "1000m"
            memory = "512Mi"
          }
          requests = {
            cpu    = "100m"
            memory = "256Mi"
          }
        }
        securityContext = {
          runAsNonRoot = true
          runAsUser    = 1000
          fsGroup      = 1000
        }
        affinity = {
          podAntiAffinity = {
            preferredDuringSchedulingIgnoredDuringExecution = [
              {
                weight = 100
                podAffinityTerm = {
                  labelSelector = {
                    matchLabels = {
                      "app.kubernetes.io/name" = "kyverno"
                      "app.kubernetes.io/component" = "admission-controller"
                    }
                  }
                  topologyKey = "kubernetes.io/hostname"
                }
              }
            ]
          }
        }
      }

      # Background Controller Configuration
      backgroundController = {
        replicas = 2
        resources = {
          limits = {
            cpu    = "1000m"
            memory = "512Mi"
          }
          requests = {
            cpu    = "100m"
            memory = "256Mi"
          }
        }
        securityContext = {
          runAsNonRoot = true
          runAsUser    = 1000
          fsGroup      = 1000
        }
      }

      # Cleanup Controller Configuration
      cleanupController = {
        replicas = 2
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

      # Reports Controller Configuration
      reportsController = {
        replicas = 2
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

      # Configuration
      config = {
        # Webhook failure policy configuration
        webhookFailurePolicy = "Ignore"  # Don't block cluster operations if Kyverno is down
        
        # Exclude system namespaces for operational safety
        excludeKyvernoNamespace = true
        excludeKubeSystemNamespace = true
        
        # Additional namespace exclusions
        resourceFilters = [
          "Event,*,*",
          "Node,*,*",
          "APIService,*,*",
          "TokenReview,*,*",
          "SubjectAccessReview,*,*",
          "SelfSubjectAccessReview,*,*",
          "Binding,*,*",
          "ReplicaSet,*,*",
          "AdmissionReport,*,*",
          "ClusterAdmissionReport,*,*",
          "BackgroundScanReport,*,*",
          "ClusterBackgroundScanReport,*,*"
        ]
      }

      # Features Configuration
      features = {
        # Enable policy exceptions for flexibility (restricted to admin namespace)
        policyExceptions = {
          enabled = true
          namespace = "kyverno"  # Only allow exceptions in the Kyverno namespace
        }
        # Enable admission reports for observability
        admissionReports = {
          enabled = true
        }
        # Enable background scanning
        backgroundScan = {
          enabled = true
        }
      }
    })
  ]

  # Dependencies are handled at the module call level
}

# 2. Wait for Kyverno admission webhooks to be ready
resource "time_sleep" "wait_for_kyverno_webhooks" {
  count = var.enable_kyverno ? 1 : 0
  
  depends_on = [
    helm_release.kyverno
  ]
  
  create_duration = "60s"  # Allow time for webhook registration
}

# 3. Verify Kyverno webhooks are registered and ready
resource "null_resource" "verify_kyverno_webhooks" {
  count = var.enable_kyverno ? 1 : 0
  
  provisioner "local-exec" {
    command = <<-EOT
      # Wait for Kyverno admission controllers to be ready
      echo "Waiting for Kyverno admission controllers to be ready..."
      kubectl --kubeconfig ${path.root}/kubeconfig wait --for=condition=ready pod -l app.kubernetes.io/component=admission-controller -n kyverno --timeout=300s
      
      # Simple verification that webhooks exist (using correct resource names)
      echo "Verifying Kyverno webhooks are registered..."
      kubectl --kubeconfig ${path.root}/kubeconfig get validatingwebhookconfigurations | grep kyverno
      kubectl --kubeconfig ${path.root}/kubeconfig get mutatingwebhookconfigurations | grep kyverno
      
      echo "Kyverno is ready for policy enforcement"
    EOT
  }
  
  depends_on = [
    time_sleep.wait_for_kyverno_webhooks
  ]
}

# 4. Deploy Kyverno Pre-built Policies
resource "helm_release" "kyverno_policies" {
  count      = var.enable_kyverno && var.enable_kyverno_policies ? 1 : 0
  name       = "kyverno-policies"
  repository = "https://kyverno.github.io/kyverno/"
  chart      = "kyverno-policies"
  version    = var.kyverno_policies_chart_version
  namespace  = "kyverno"
  create_namespace = false

  values = [
    yamlencode({
      # Pod Security Standards - Baseline profile
      podSecurityStandard = "baseline"
      
      # Include specific policy categories
      include = [
        "pod-security-standard-baseline",
        "best-practices",
        "security"
      ]

      # Exclude policies that might conflict with service mesh requirements
      exclude = [
        "restrict-seccomp-strict",  # May conflict with Istio sidecars
        "require-run-as-non-root-user"  # May conflict with init containers
      ]

      # Policy enforcement mode
      policyViolationAction = "enforce"

      # Namespace exclusions (same as main Kyverno config)
      namespaceSelector = {
        matchExpressions = [
          {
            key      = "kubernetes.io/metadata.name"
            operator = "NotIn"
            values   = var.kyverno_policy_exclusions
          }
        ]
      }

      # Background scanning configuration
      background = true
    })
  ]

  depends_on = [
    helm_release.kyverno
  ]
}

# 5. Deploy custom cluster policies using manifests (for future use)
# These policies will only be deployed when the manifest files contain actual policy definitions

resource "kubectl_manifest" "kyverno_custom_kgateway_policy" {
  count = var.enable_kyverno && length(trimspace(file("${path.module}/manifests/custom-policy-kgateway.yaml"))) > 10 ? 1 : 0
  yaml_body = file("${path.module}/manifests/custom-policy-kgateway.yaml")

  depends_on = [
    null_resource.verify_kyverno_webhooks
  ]
}

resource "kubectl_manifest" "kyverno_custom_network_policy" {
  count = var.enable_kyverno && length(trimspace(file("${path.module}/manifests/custom-policy-network.yaml"))) > 10 ? 1 : 0
  yaml_body = file("${path.module}/manifests/custom-policy-network.yaml")

  depends_on = [
    null_resource.verify_kyverno_webhooks
  ]
}

resource "kubectl_manifest" "kyverno_custom_waypoint_policy" {
  count = var.enable_kyverno && length(trimspace(file("${path.module}/manifests/custom-policy-waypoint.yaml"))) > 10 ? 1 : 0
  yaml_body = file("${path.module}/manifests/custom-policy-waypoint.yaml")

  depends_on = [
    null_resource.verify_kyverno_webhooks
  ]
}

# 6. Deploy Policy Reporter UI (conditional on Prometheus Operator)
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

# 7. Deploy Policy Reporter UI with Prometheus Operator integration
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
    null_resource.verify_kyverno_webhooks
    # Module dependencies handled at module level
  ]
}

# 8. Configure ReferenceGrant for Policy Reporter UI
resource "kubectl_manifest" "policy_reporter_reference_grant" {
  count = var.enable_kyverno && var.enable_policy_reporter_ui ? 1 : 0
  yaml_body = templatefile("${path.module}/manifests/policy-reporter-reference-grant.yaml", {})

  depends_on = [
    helm_release.policy_reporter_basic,
    helm_release.policy_reporter_full
  ]
}

# 9. Configure HTTPRoute for Policy Reporter UI access via Gateway API
resource "kubectl_manifest" "policy_reporter_httproute" {
  count = var.enable_kyverno && var.enable_policy_reporter_ui ? 1 : 0
  yaml_body = templatefile("${path.module}/manifests/policy-reporter-httproute.yaml", {
    domain_name = var.domain_name
  })

  depends_on = [
    helm_release.policy_reporter_basic,
    helm_release.policy_reporter_full,
    kubectl_manifest.policy_reporter_reference_grant
    # Gateway dependencies handled at module level
  ]
}