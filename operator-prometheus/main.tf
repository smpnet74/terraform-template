# Prometheus Operator Module
# Deploys kube-prometheus-stack with ServiceMonitors for cluster components

# 1. Deploy Prometheus Operator using Helm chart
resource "helm_release" "prometheus_operator" {
  count      = var.enable_prometheus_operator ? 1 : 0
  name       = "kube-prometheus-stack"
  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "kube-prometheus-stack"
  version    = var.prometheus_operator_chart_version
  namespace  = var.monitoring_namespace
  create_namespace = true
  
  # Allow longer timeout for initial CRD installation
  timeout = 600
  
  values = [
    yamlencode({
      # Prometheus Operator Configuration
      prometheusOperator = {
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
      
      # Prometheus Server Configuration
      prometheus = {
        prometheusSpec = {
          # Resource configuration
          resources = {
            limits = {
              cpu    = "1000m"
              memory = "2Gi"
            }
            requests = {
              cpu    = "200m"
              memory = "512Mi"
            }
          }
          
          # Security context
          securityContext = {
            runAsNonRoot = true
            runAsUser    = 1000
            fsGroup      = 1000
          }
          
          # Storage configuration (ephemeral for now)
          storageSpec = {
            volumeClaimTemplate = {
              spec = {
                accessModes = ["ReadWriteOnce"]
                resources = {
                  requests = {
                    storage = "10Gi"
                  }
                }
              }
            }
          }
          
          # Service discovery configuration
          serviceMonitorSelectorNilUsesHelmValues = false
          serviceMonitorNamespaceSelector = {}
          serviceMonitorSelector = {}
          
          # Enable service discovery across all namespaces
          ruleSelector = {}
          ruleNamespaceSelector = {}
          
          # Retention policy
          retention = "7d"
          retentionSize = "8GiB"
          
          # PVC cleanup policy - delete PVCs when StatefulSet is deleted
          persistentVolumeClaimRetentionPolicy = {
            whenDeleted = "Delete"  # Automatically delete PVCs on terraform destroy
            whenScaled  = "Retain"  # Keep PVCs when scaling down (preserve data)
          }
        }
      }
      
      # Alertmanager Configuration
      alertmanager = {
        alertmanagerSpec = {
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
          storage = {
            volumeClaimTemplate = {
              spec = {
                accessModes = ["ReadWriteOnce"]
                resources = {
                  requests = {
                    storage = "2Gi"
                  }
                }
              }
            }
          }
          
          # PVC cleanup policy - delete PVCs when StatefulSet is deleted
          persistentVolumeClaimRetentionPolicy = {
            whenDeleted = "Delete"  # Automatically delete PVCs on terraform destroy
            whenScaled  = "Retain"  # Keep PVCs when scaling down (preserve data)
          }
        }
      }
      
      # Disable built-in Grafana (we have our own)
      grafana = {
        enabled = false
      }
      
      # Node Exporter Configuration
      nodeExporter = {
        enabled = true
      }
      
      # kube-state-metrics Configuration  
      kubeStateMetrics = {
        enabled = true
      }
      
      # Default rules for Kubernetes monitoring
      defaultRules = {
        create = true
        rules = {
          alertmanager = true
          etcd = false  # Not applicable for managed clusters
          configReloaders = true
          general = true
          k8s = true
          kubeApiserverAvailability = true
          kubeApiserverBurnrate = true
          kubeApiserverHistogram = true
          kubeApiserverSlos = true
          kubeControllerManager = false  # Not accessible in managed clusters
          kubelet = true
          kubeProxy = false  # Cilium handles this
          kubePrometheusGeneral = true
          kubePrometheusNodeRecording = true
          kubernetesApps = true
          kubernetesResources = true
          kubernetesStorage = true
          kubernetesSystem = true
          kubeScheduler = false  # Not accessible in managed clusters
          kubeStateMetrics = true
          network = true
          node = true
          nodeExporterAlerting = true
          nodeExporterRecording = true
          prometheus = true
          prometheusOperator = true
        }
      }
      
      # Common labels for all resources
      commonLabels = {
        "app.kubernetes.io/part-of" = "kube-prometheus-stack"
      }
    })
  ]
  
  # Dependencies are handled at the module call level
}

# 2. Wait for Prometheus Operator CRDs to be ready
resource "time_sleep" "wait_for_prometheus_operator" {
  count = var.enable_prometheus_operator ? 1 : 0
  
  depends_on = [
    helm_release.prometheus_operator
  ]
  
  create_duration = "60s"  # Allow time for CRDs and operator to be ready
}

# 3. Deploy ServiceMonitors for cluster components using manifests
resource "kubectl_manifest" "istio_control_plane_servicemonitor" {
  count = var.enable_prometheus_operator ? 1 : 0
  yaml_body = templatefile("${path.module}/manifests/istio-control-plane-servicemonitor.yaml", {
    monitoring_namespace = var.monitoring_namespace
  })

  depends_on = [
    time_sleep.wait_for_prometheus_operator
  ]
}

resource "kubectl_manifest" "cilium_servicemonitor" {
  count = var.enable_prometheus_operator ? 1 : 0
  yaml_body = templatefile("${path.module}/manifests/cilium-servicemonitor.yaml", {
    monitoring_namespace = var.monitoring_namespace
  })

  depends_on = [
    time_sleep.wait_for_prometheus_operator
  ]
}

resource "kubectl_manifest" "kgateway_servicemonitor" {
  count = var.enable_prometheus_operator ? 1 : 0
  yaml_body = templatefile("${path.module}/manifests/kgateway-servicemonitor.yaml", {
    monitoring_namespace = var.monitoring_namespace
  })

  depends_on = [
    time_sleep.wait_for_prometheus_operator
  ]
}