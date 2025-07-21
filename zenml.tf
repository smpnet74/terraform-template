# zenml.tf

# 1. Create a dedicated namespace for ZenML
resource "kubernetes_namespace" "zenml" {
  count = var.enable_zenml ? 1 : 0
  metadata {
    name = var.zenml_namespace
    labels = {
      "app.kubernetes.io/name"    = "zenml"
      "istio.io/dataplane-mode" = "ambient" # Required for Istio Ambient Mesh
    }
  }
}

# 2. Generate random passwords for DB and admin user
resource "random_password" "zenml_db" {
  count   = var.enable_zenml ? 1 : 0
  length  = 24
  special = false
}

resource "random_password" "zenml_admin_token" {
  count   = var.enable_zenml ? 1 : 0
  length  = 64
  special = false
}

# 3. Create secret for the database password
# This secret will be used by KubeBlocks to set the initial PostgreSQL password.
resource "kubernetes_secret" "zenml_db_creds" {
  count = var.enable_zenml ? 1 : 0
  metadata {
    name      = "zenml-postgres-auth"
    namespace = var.zenml_namespace
  }
  data = {
    "password" = random_password.zenml_db[0].result
    "username" = "zenml"
  }
}

# 4. Create ServiceAccount for PostgreSQL
resource "kubectl_manifest" "zenml_postgres_sa" {
  count      = var.enable_zenml ? 1 : 0
  yaml_body  = <<-YAML
apiVersion: v1
kind: ServiceAccount
metadata:
  name: kb-psa-zenml-postgres
  namespace: ${var.zenml_namespace}
YAML
  depends_on = [kubernetes_namespace.zenml]
}

# 5. Provision a PostgreSQL database using KubeBlocks
# This resource explicitly depends on the KubeBlocks Helm release to ensure
# the operator is running before this cluster is created.
resource "kubectl_manifest" "zenml_postgres_cluster" {
  count      = var.enable_zenml ? 1 : 0
  yaml_body  = <<-YAML
apiVersion: apps.kubeblocks.io/v1
kind: Cluster
metadata:
  name: zenml-postgres
  namespace: ${var.zenml_namespace}
spec:
  clusterDef: postgresql
  terminationPolicy: WipeOut
  componentSpecs:
  - name: postgresql
    componentDef: postgresql
    replicas: 1
    serviceAccountName: kb-psa-zenml-postgres
    # This tells KubeBlocks to use the secret we created for the initial user/password.
    # The user 'zenml' will be created with the password from the secret.
    userPasswordSecret:
      name: ${kubernetes_secret.zenml_db_creds[0].metadata[0].name}
    resources:
      limits:
        cpu: 200m
        memory: 512Mi
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
            storage: 5Gi
        storageClassName: civo-volume
YAML
  depends_on = [helm_release.kubeblocks, kubectl_manifest.zenml_postgres_sa, kubernetes_secret.zenml_db_creds]
}

# 6. Create the Civo Object Store bucket for ZenML artifacts
resource "civo_object_store" "zenml_artifacts" {
  count       = var.enable_zenml ? 1 : 0
  name        = var.zenml_artifact_bucket
  region      = var.region
  max_size_gb = var.zenml_artifact_bucket_size
}

# 7. S3 credentials will be configured later via ZenML CLI/UI
# No need to create Kubernetes secrets during Terraform deployment
# Object store is ready immediately after creation - no wait needed

# 9. Wait for PostgreSQL cluster to be ready (smart wait based on actual status)
resource "null_resource" "wait_for_postgres_ready" {
  count = var.enable_zenml ? 1 : 0
  
  provisioner "local-exec" {
    command = <<-EOT
      echo "Waiting for Kubernetes API server to be ready..."
      # First, wait for API server connectivity
      for i in {1..10}; do
        if kubectl --kubeconfig=${path.module}/kubeconfig get nodes >/dev/null 2>&1; then
          echo "API server is responding"
          break
        fi
        echo "API server not ready, waiting... ($i/10)"
        sleep 30
      done
      
      echo "Waiting for PostgreSQL cluster to be ready..."
      kubectl --kubeconfig=${path.module}/kubeconfig wait --for=condition=Ready cluster/zenml-postgres -n ${var.zenml_namespace} --timeout=300s
    EOT
  }
  
  depends_on = [kubectl_manifest.zenml_postgres_cluster]
}

# 9.5. KubeBlocks operator cleanup for PostgreSQL cluster
# This trusts the KubeBlocks operator to handle proper lifecycle management
resource "null_resource" "zenml_postgres_cleanup" {
  count = var.enable_zenml ? 1 : 0
  
  # This runs when the resource is destroyed
  provisioner "local-exec" {
    when    = destroy
    command = <<-EOT
      echo "🚀 Starting KubeBlocks operator cleanup for ZenML..."
      
      # Let KubeBlocks operator handle proper cleanup
      echo "📋 Operator-managed cleanup"
      
      # Ensure termination policy is set to WipeOut for complete cleanup
      echo "  Setting termination policy to WipeOut..."
      kubectl --kubeconfig=./kubeconfig patch cluster zenml-postgres -n zenml-system \
        -p '{"spec":{"terminationPolicy":"WipeOut"}}' --type=merge 2>/dev/null || true
      
      # Delete the cluster resource to trigger operator cleanup
      echo "  Deleting cluster resource (letting operator handle cleanup)..."
      kubectl --kubeconfig=./kubeconfig delete cluster zenml-postgres -n zenml-system \
        --timeout=120s --ignore-not-found=true || true
      
      # Wait for operator to process the deletion
      echo "  Waiting for KubeBlocks operator to complete cleanup..."
      for i in {1..12}; do
        if ! kubectl --kubeconfig=./kubeconfig get cluster zenml-postgres -n zenml-system >/dev/null 2>&1; then
          echo "  ✅ Operator cleanup completed successfully"
          operator_cleanup_success=true
          break
        fi
        echo "  ⏳ Waiting for operator cleanup... ($i/12)"
        sleep 10
      done
      
      # Verify cleanup completion
      if [ "$operator_cleanup_success" = true ]; then
        echo "🎉 KubeBlocks operator successfully cleaned up all resources"
      else
        echo "⚠️  KubeBlocks operator cleanup timed out after 2 minutes"
        echo "   This may indicate the operator needs attention"
      fi
      
      echo "🏁 ZenML cleanup completed"
    EOT
  }
  
  # Standalone cleanup - doesn't depend on other resources to avoid circular dependencies
  # The script handles missing resources gracefully with --ignore-not-found
  
  # Trigger recreation when zenml is enabled/disabled
  triggers = {
    zenml_enabled = var.enable_zenml
  }
}

# 10. Deploy ZenML Server using the official Helm chart
resource "helm_release" "zenml" {
  count     = var.enable_zenml ? 1 : 0
  name      = "zenml"
  chart     = "oci://public.ecr.aws/zenml/zenml"
  # Note: Remove version to use latest, or check available versions
  # version   = var.zenml_chart_version
  namespace = var.zenml_namespace

  values = [
    yamlencode({
      image = {
        tag = var.zenml_server_version
      }
      
      resources = {
        limits = {
          cpu    = "500m"
          memory = "1Gi"
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
      
      # Configure external PostgreSQL database
      database = {
        external = {
          type     = "postgres"
          host     = "zenml-postgres-postgresql.${var.zenml_namespace}.svc.cluster.local"
          port     = 5432
          username = "zenml"
          password = random_password.zenml_db[0].result
          database = "postgres"
        }
      }
      
      zenml = {
        server = {
          admin_token = random_password.zenml_admin_token[0].result
        }
        # Artifact store configuration is typically done via CLI, not Helm values
      }
    })
  ]

  depends_on = [
    null_resource.wait_for_postgres_ready,
    civo_object_store.zenml_artifacts
  ]
}

# 11. Expose ZenML UI via Gateway API
resource "kubectl_manifest" "httproute_zenml" {
  count      = var.enable_zenml ? 1 : 0
  yaml_body  = <<-YAML
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: zenml-ui
  namespace: default
  annotations:
    kyverno.io/policy-exempt: "true"
spec:
  parentRefs:
  - name: default-gateway
    namespace: default
    kind: Gateway
  hostnames:
  - "zenml.${var.domain_name}"
  rules:
  - matches:
    - path:
        type: PathPrefix
        value: "/"
    backendRefs:
    - name: zenml
      namespace: ${var.zenml_namespace}
      port: 80
      kind: Service
YAML
  depends_on = [helm_release.zenml, kubectl_manifest.default_gateway]
}

# 12. Create ReferenceGrant to allow cross-namespace routing
resource "kubectl_manifest" "refgrant_zenml" {
  count      = var.enable_zenml ? 1 : 0
  yaml_body  = <<-YAML
apiVersion: gateway.networking.k8s.io/v1beta1
kind: ReferenceGrant
metadata:
  name: zenml-access
  namespace: ${var.zenml_namespace}
spec:
  from:
  - group: gateway.networking.k8s.io
    kind: HTTPRoute
    namespace: default
  to:
  - group: ""
    kind: Service
    name: zenml
YAML
  depends_on = [helm_release.zenml]
}

# 13. Create ServiceMonitor for Prometheus
# This allows the existing Prometheus stack to automatically discover and scrape
# metrics from the ZenML server.
resource "kubectl_manifest" "zenml_servicemonitor" {
  count = var.enable_zenml && var.enable_prometheus_operator ? 1 : 0
  yaml_body = <<-YAML
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: zenml-server
  namespace: ${var.monitoring_namespace} # Deploys to the monitoring namespace
  labels:
    release: kube-prometheus-stack # Standard label for the Prometheus operator
spec:
  selector:
    matchLabels:
      app.kubernetes.io/name: zenml-server
  namespaceSelector:
    matchNames:
    - ${var.zenml_namespace}
  endpoints:
  - port: http
    path: /api/v1/health
    interval: 30s
YAML
  depends_on = [helm_release.zenml]
}

# 14. Update Kyverno policies to exclude zenml-system namespace
resource "kubectl_manifest" "kyverno_zenml_exclusion" {
  count = var.enable_zenml && var.enable_kyverno ? 1 : 0
  yaml_body = <<-YAML
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: require-resource-requests-zenml-updated
  annotations:
    policies.kyverno.io/title: Require Resource Requests (Updated for ZenML)
    policies.kyverno.io/category: Best Practices
    policies.kyverno.io/severity: medium
    policies.kyverno.io/subject: Pod
spec:
  validationFailureAction: Audit
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
          - ${var.zenml_namespace}  # Add ZenML namespace exclusion
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