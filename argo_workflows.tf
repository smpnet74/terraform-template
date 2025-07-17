resource "helm_release" "argo_workflows" {
  count      = var.enable_argo_workflows ? 1 : 0
  name       = "argo-workflows"
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-workflows"
  version    = var.argo_workflows_chart_version
  namespace  = "argo"
  create_namespace = true

  values = [
    yamlencode({
      server = {
        enabled = true
        extraArgs = [
          "--auth-mode=basic"
        ]
        secure = false
        basicAuth = {
          enabled = true
          secretName = "argo-workflows-auth"
        }
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

  depends_on = [
    time_sleep.wait_for_cluster
  ]
}

# Argo Events for EventSources and Sensors
resource "helm_release" "argo_events" {
  count      = var.enable_argo_workflows ? 1 : 0
  name       = "argo-events"
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-events"
  version    = var.argo_events_chart_version
  namespace  = "argo"
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

# EventBus configuration for Argo Events
resource "kubectl_manifest" "eventbus_default" {
  count = var.enable_argo_workflows ? 1 : 0
  yaml_body = <<-YAML
apiVersion: argoproj.io/v1alpha1
kind: EventBus
metadata:
  name: default
  namespace: argo
spec:
  jetstream:
    version: "${var.jetstream_version}"
    replicas: 3
    persistence:
      storageClassName: "civo-volume"
      accessMode: ReadWriteOnce
      volumeSize: 10Gi
YAML

  depends_on = [
    helm_release.argo_events
  ]
}

# Basic auth secret for Argo Workflows UI
resource "kubernetes_secret" "argo_workflows_auth" {
  count = var.enable_argo_workflows ? 1 : 0
  metadata {
    name      = "argo-workflows-auth"
    namespace = "argo"
  }
  data = {
    username = var.argo_workflows_username
    password = var.argo_workflows_password
  }

  depends_on = [
    helm_release.argo_workflows
  ]
}


resource "kubectl_manifest" "httproute_argo_workflows" {
  count = var.enable_argo_workflows ? 1 : 0
  yaml_body = <<-YAML
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: argo-workflows
  namespace: argo
spec:
  parentRefs:
    - name: default-gateway
      namespace: default
      kind: Gateway
  hostnames:
    - "argo-workflows.${var.domain_name}"
  rules:
    - matches:
        - path:
            type: PathPrefix
            value: /
      backendRefs:
        - name: argo-workflows-server
          port: 2746
          kind: Service
YAML

  depends_on = [
    helm_release.argo_workflows,
    kubectl_manifest.default_gateway
  ]
}

resource "kubectl_manifest" "reference_grant_argo_workflows" {
  count = var.enable_argo_workflows ? 1 : 0
  yaml_body = <<-YAML
apiVersion: gateway.networking.k8s.io/v1beta1
kind: ReferenceGrant
metadata:
  name: allow-argo-to-default-gateway
  namespace: default
spec:
  from:
    - group: gateway.networking.k8s.io
      kind: HTTPRoute
      namespace: argo
  to:
    - group: gateway.networking.k8s.io
      kind: Gateway
      name: default-gateway
YAML

  depends_on = [
    helm_release.argo_workflows,
    kubectl_manifest.default_gateway
  ]
}

