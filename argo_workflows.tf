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
    version: "2.9.6"
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

resource "kubernetes_secret" "docker_config" {
  count = var.enable_argo_workflows ? 1 : 0
  metadata {
    name      = "docker-config"
    namespace = "argo"
  }
  data = {
    ".dockerconfigjson" = "{\"auths\":{\"https://index.docker.io/v1/\":{\"auth\":\"YOUR_DOCKER_AUTH_TOKEN_HERE\"}}}"
  }
  type = "kubernetes.io/dockerconfigjson"

  depends_on = [
    helm_release.argo_workflows
  ]
}

resource "kubernetes_secret" "git_credentials" {
  count = var.enable_argo_workflows ? 1 : 0
  metadata {
    name      = "git-credentials"
    namespace = "argo"
  }
  data = {
    username = "YOUR_GIT_USERNAME"
    token    = "YOUR_GIT_PAT"
  }

  depends_on = [
    helm_release.argo_workflows
  ]
}

resource "kubectl_manifest" "workflow_template" {
  count = var.enable_argo_workflows ? 1 : 0
  yaml_body = <<-YAML
apiVersion: argoproj.io/v1alpha1
kind: WorkflowTemplate
metadata:
  name: ci-build-template
  namespace: argo
spec:
  entrypoint: build-and-push
  arguments:
    parameters:
      - name: repo_url
      - name: image_name
      - name: manifest_repo_url
      - name: manifest_file_path

  templates:
    - name: build-and-push
      steps:
        - - name: build
            template: kaniko-build
            arguments:
              parameters:
                - name: repo_url
                  value: "{{workflow.parameters.repo_url}}"
                - name: image_name
                  value: "{{workflow.parameters.image_name}}"

        - - name: update-manifest
            template: update-manifest
            arguments:
              parameters:
                - name: manifest_repo_url
                  value: "{{workflow.parameters.manifest_repo_url}}"
                - name: manifest_file_path
                  value: "{{workflow.parameters.manifest_file_path}}"
                - name: new_image
                  value: "{{steps.build.outputs.parameters.image_tag}}"

    - name: kaniko-build
      inputs:
        parameters:
          - name: repo_url
          - name: image_name
      outputs:
        parameters:
          - name: image_tag
            value: "{{inputs.parameters.image_name}}:{{workflow.outputs.parameters.git_sha_short}}"
      container:
        image: gcr.io/kaniko-project/executor:v1.9.0
        args:
          - "--dockerfile=./Dockerfile"
          - "--context={{inputs.parameters.repo_url}}#{{workflow.outputs.parameters.git_sha}}"
          - "--destination={{steps.build.outputs.parameters.image_tag}}"
        volumeMounts:
          - name: docker-config
            mountPath: /kaniko/.docker/
      volumes:
        - name: docker-config
          secret:
            secretName: docker-config

    - name: update-manifest
      inputs:
        parameters:
          - name: manifest_repo_url
          - name: manifest_file_path
          - name: new_image
      container:
        image: alpine/git:latest
        command: ["sh", "-c"]
        args:
          - |
            git config --global user.email "ci@example.com"
            git config --global user.name "CI Bot"
            git clone https://{{secrets.git-credentials.username}}:{{secrets.git-credentials.token}}@{{inputs.parameters.manifest_repo_url}} /tmp/manifests
            cd /tmp/manifests
            sed -i "s|image: .*|image: {{inputs.parameters.new_image}}|" "{{inputs.parameters.manifest_file_path}}"
            git add .
            git commit -m "Update image to {{inputs.parameters.new_image}}"
            git push
YAML
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

