# Argo Workflows Feature Module - Cluster-Wide Configuration
# Deploys Argo Workflows, Argo Events, EventBus with cluster-wide capabilities

# 1. Deploy Argo Workflows using Helm chart with cluster-wide configuration
resource "helm_release" "argo_workflows" {
  count            = var.enable_argo_workflows ? 1 : 0
  name             = "argo-workflows"
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-workflows"
  version          = var.argo_workflows_chart_version
  namespace        = var.argo_namespace
  create_namespace = true

  values = [
    yamlencode({
      # Workflow Controller Configuration
      controller = {
        enabled = true
        # Enable cluster-wide workflow management
        clusterWorkflowTemplates = {
          enabled = true
        }
        # Configure controller to watch all namespaces
        workflowNamespaces = []
        # Enhanced RBAC for cluster-wide operations
        rbac = {
          create = true
          # Grant cluster-wide permissions
          rules = [
            {
              apiGroups = [""]
              resources = ["pods", "pods/exec", "pods/log", "events", "serviceaccounts", "secrets", "configmaps"]
              verbs = ["*"]
            },
            {
              apiGroups = ["apps"]
              resources = ["deployments", "replicasets"]
              verbs = ["*"]
            },
            {
              apiGroups = ["argoproj.io"]
              resources = ["workflows", "workflows/finalizers", "workflowtemplates", "cronworkflows", "clusterworkflowtemplates"]
              verbs = ["*"]
            },
            {
              apiGroups = ["policy"]
              resources = ["poddisruptionbudgets"]
              verbs = ["create", "get", "delete"]
            }
          ]
        }
        serviceAccount = {
          create = true
          name = "argo-workflow-controller"
        }
      }
      # Workflow Server Configuration
      server = {
        enabled = true
        extraArgs = [
          "--auth-mode=server",
          "--secure=false",
          # Enable cluster-wide workflow visibility
          "--namespaced=false"
        ]
        secure = false
        serviceAccount = {
          create = true
          name = "argo-server"
        }
        # Server RBAC for cluster-wide access
        rbac = {
          create = true
          rules = [
            {
              apiGroups = [""]
              resources = ["pods", "pods/exec", "pods/log", "events", "serviceaccounts", "secrets", "configmaps"]
              verbs = ["get", "list", "watch"]
            },
            {
              apiGroups = ["apps"]
              resources = ["deployments"]
              verbs = ["get", "list", "watch"]
            },
            {
              apiGroups = ["argoproj.io"]
              resources = ["workflows", "workflowtemplates", "cronworkflows", "clusterworkflowtemplates"]
              verbs = ["*"]
            }
          ]
        }
      }
      # Workflow Executor Configuration
      workflow = {
        serviceAccount = {
          create = true
          name = "argo-workflow"
        }
        rbac = {
          create = true
        }
      }
      # Enable cluster-wide workflow templates
      useDefaultArtifactRepo = true
      useStaticCredentials = true
    })
  ]
}

# 2. Deploy Argo Events for cluster-wide EventSources and Sensors
resource "helm_release" "argo_events" {
  count            = var.enable_argo_workflows ? 1 : 0
  name             = "argo-events"
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-events"
  version          = var.argo_events_chart_version
  namespace        = var.argo_namespace
  create_namespace = false

  values = [
    yamlencode({
      # EventBus Controller Configuration
      eventbus = {
        enabled = true
        jetstream = {
          enabled = true
        }
      }
      # EventSource Controller with cluster-wide capabilities
      eventsource = {
        enabled = true
        # Enable cluster-wide event source management
        rbac = {
          create = true
          rules = [
            {
              apiGroups = [""]
              resources = ["events", "configmaps", "secrets", "services", "pods"]
              verbs = ["*"]
            },
            {
              apiGroups = ["argoproj.io"]
              resources = ["eventsources", "sensors", "eventbus"]
              verbs = ["*"]
            },
            {
              apiGroups = ["apps"]
              resources = ["deployments"]
              verbs = ["*"]
            }
          ]
        }
        serviceAccount = {
          create = true
          name = "argo-events-eventsource-controller"
        }
      }
      # Sensor Controller with cluster-wide capabilities
      sensor = {
        enabled = true
        rbac = {
          create = true
          rules = [
            {
              apiGroups = [""]
              resources = ["events", "configmaps", "secrets", "services", "pods"]
              verbs = ["*"]
            },
            {
              apiGroups = ["argoproj.io"]
              resources = ["sensors", "eventsources", "workflows", "workflowtemplates"]
              verbs = ["*"]
            },
            {
              apiGroups = ["apps"]
              resources = ["deployments"]
              verbs = ["*"]
            }
          ]
        }
        serviceAccount = {
          create = true
          name = "argo-events-sensor-controller"
        }
      }
      # EventBus Controller
      eventbusController = {
        rbac = {
          create = true
        }
        serviceAccount = {
          create = true
          name = "argo-events-eventbus-controller"
        }
      }
    })
  ]

  depends_on = [
    helm_release.argo_workflows
  ]
}

# 3. Deploy EventBus configuration for Argo Events
resource "kubectl_manifest" "eventbus_default" {
  count = var.enable_argo_workflows ? 1 : 0
  yaml_body = templatefile("${path.module}/manifests/eventbus.yaml", {
    jetstream_version = var.jetstream_version,
    argo_namespace = var.argo_namespace
  })

  depends_on = [
    helm_release.argo_events
  ]
}

# 4. Configure HTTPRoute for Argo Workflows UI
resource "kubectl_manifest" "httproute_argo_workflows" {
  count = var.enable_argo_workflows ? 1 : 0
  yaml_body = templatefile("${path.module}/manifests/httproute.yaml", {
    domain_name = var.domain_name,
    argo_namespace = var.argo_namespace
  })

  depends_on = [
    helm_release.argo_workflows
  ]
}

# 5. Deploy cluster-wide RBAC for enhanced permissions
resource "kubectl_manifest" "cluster_rbac_argo" {
  count = var.enable_argo_workflows ? 1 : 0
  yaml_body = templatefile("${path.module}/manifests/cluster-rbac.yaml", {
    argo_namespace = var.argo_namespace
  })

  depends_on = [
    helm_release.argo_workflows,
    helm_release.argo_events
  ]
}

# 6. Deploy cluster-wide workflow templates for common CI/CD patterns
resource "kubectl_manifest" "cluster_workflow_templates" {
  count = var.enable_argo_workflows ? 1 : 0
  yaml_body = templatefile("${path.module}/manifests/cluster-workflow-templates.yaml", {
    argo_namespace = var.argo_namespace
  })

  depends_on = [
    kubectl_manifest.cluster_rbac_argo
  ]
}

# 7. Configure ReferenceGrant to allow HTTPRoute to reference Gateway
resource "kubectl_manifest" "reference_grant_argo_workflows" {
  count = var.enable_argo_workflows ? 1 : 0
  yaml_body = templatefile("${path.module}/manifests/reference-grant.yaml", {
    argo_namespace = var.argo_namespace
  })

  depends_on = [
    helm_release.argo_workflows
  ]
}
