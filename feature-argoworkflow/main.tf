# Argo Workflows Feature Module
# Deploys Argo Workflows, Argo Events, EventBus, and Gateway integration

# 1. Deploy Argo Workflows using Helm chart
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
      server = {
        enabled = true
        extraArgs = [
          "--auth-mode=server"
        ]
        secure = false
      }
      controller = {
        enabled = true
      }
      workflow = {
        serviceAccount = {
          create = true
        }
      }
    })
  ]
}

# 2. Deploy Argo Events for EventSources and Sensors
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
      eventbus = {
        enabled = true
        jetstream = {
          enabled = true
        }
      }
      eventsource = {
        enabled = true
      }
      sensor = {
        enabled = true
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

# 5. Configure ReferenceGrant to allow HTTPRoute to reference Gateway
resource "kubectl_manifest" "reference_grant_argo_workflows" {
  count = var.enable_argo_workflows ? 1 : 0
  yaml_body = templatefile("${path.module}/manifests/reference-grant.yaml", {
    argo_namespace = var.argo_namespace
  })

  depends_on = [
    helm_release.argo_workflows
  ]
}
