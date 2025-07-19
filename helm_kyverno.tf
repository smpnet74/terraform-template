# Kyverno Policy Engine - Kubernetes-native policy management
# https://kyverno.io/docs/installation/

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

  depends_on = [
    time_sleep.wait_for_cluster,
    null_resource.cilium_upgrade  # Ensure Cilium is ready before policies
  ]
}

# Wait for Kyverno admission webhooks to be ready
resource "time_sleep" "wait_for_kyverno_webhooks" {
  count = var.enable_kyverno ? 1 : 0
  
  depends_on = [
    helm_release.kyverno
  ]
  
  create_duration = "60s"  # Allow time for webhook registration
}

# Verify Kyverno webhooks are registered and ready
resource "null_resource" "verify_kyverno_webhooks" {
  count = var.enable_kyverno ? 1 : 0
  
  provisioner "local-exec" {
    command = <<-EOT
      # Wait for Kyverno admission controllers to be ready
      echo "Waiting for Kyverno admission controllers to be ready..."
      kubectl --kubeconfig ${path.module}/kubeconfig wait --for=condition=ready pod -l app.kubernetes.io/component=admission-controller -n kyverno --timeout=300s
      
      # Simple verification that webhooks exist (using correct resource names)
      echo "Verifying Kyverno webhooks are registered..."
      kubectl --kubeconfig ${path.module}/kubeconfig get validatingwebhookconfigurations | grep kyverno
      kubectl --kubeconfig ${path.module}/kubeconfig get mutatingwebhookconfigurations | grep kyverno
      
      echo "Kyverno is ready for policy enforcement"
    EOT
  }
  
  depends_on = [
    time_sleep.wait_for_kyverno_webhooks
  ]
}