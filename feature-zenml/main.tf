# ZenML Feature - Complete deployment with PostgreSQL backend and Civo Object Store

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
  count     = var.enable_zenml ? 1 : 0
  yaml_body = templatefile("${path.module}/manifests/postgres-service-account.yaml", {
    zenml_namespace = var.zenml_namespace
  })
  depends_on = [kubernetes_namespace.zenml]
}

# 5. Provision a PostgreSQL database using KubeBlocks
# This resource explicitly depends on the KubeBlocks Helm release to ensure
# the operator is running before this cluster is created.
resource "kubectl_manifest" "zenml_postgres_cluster" {
  count     = var.enable_zenml ? 1 : 0
  yaml_body = templatefile("${path.module}/manifests/postgres-cluster.yaml", {
    zenml_namespace       = var.zenml_namespace
    zenml_db_secret_name  = kubernetes_secret.zenml_db_creds[0].metadata[0].name
  })
  depends_on = [
    kubectl_manifest.zenml_postgres_sa, 
    kubernetes_secret.zenml_db_creds
  ]
  
  # Dependencies are handled via the module's depends_on attribute
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
        if kubectl --kubeconfig=${path.root}/kubeconfig get nodes >/dev/null 2>&1; then
          echo "API server is responding"
          break
        fi
        echo "API server not ready, waiting... ($i/10)"
        sleep 30
      done
      
      echo "Waiting for PostgreSQL cluster to be ready..."
      kubectl --kubeconfig=${path.root}/kubeconfig wait --for=condition=Ready cluster/zenml-postgres -n ${var.zenml_namespace} --timeout=300s
    EOT
  }
  
  depends_on = [kubectl_manifest.zenml_postgres_cluster]
}

# 9.5. KubeBlocks operator cleanup for PostgreSQL cluster
# This trusts the KubeBlocks operator to handle proper lifecycle management
resource "null_resource" "zenml_postgres_cleanup" {
  count = var.enable_zenml ? 1 : 0
  
  # Store values needed during destroy in triggers
  triggers = {
    zenml_enabled = var.enable_zenml
    zenml_namespace = var.zenml_namespace
    kubeconfig_path = "${path.root}/kubeconfig"
  }
  
  # This runs when the resource is destroyed
  provisioner "local-exec" {
    when    = destroy
    command = <<-EOT
      echo "🚀 Starting KubeBlocks operator cleanup for ZenML..."
      
      # Let KubeBlocks operator handle proper cleanup
      echo "📋 Operator-managed cleanup"
      
      # Ensure termination policy is set to WipeOut for complete cleanup
      echo "  Setting termination policy to WipeOut..."
      kubectl --kubeconfig=${self.triggers.kubeconfig_path} patch cluster zenml-postgres -n ${self.triggers.zenml_namespace} \
        -p '{"spec":{"terminationPolicy":"WipeOut"}}' --type=merge 2>/dev/null || true
      
      # Delete the cluster resource to trigger operator cleanup
      echo "  Deleting cluster resource (letting operator handle cleanup)..."
      kubectl --kubeconfig=${self.triggers.kubeconfig_path} delete cluster zenml-postgres -n ${self.triggers.zenml_namespace} \
        --timeout=120s --ignore-not-found=true || true
      
      # Wait for operator to process the deletion
      echo "  Waiting for KubeBlocks operator to complete cleanup..."
      operator_cleanup_success=false
      for i in {1..12}; do
        if ! kubectl --kubeconfig=${self.triggers.kubeconfig_path} get cluster zenml-postgres -n ${self.triggers.zenml_namespace} >/dev/null 2>&1; then
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
  count     = var.enable_zenml ? 1 : 0
  yaml_body = templatefile("${path.module}/manifests/zenml-httproute.yaml", {
    domain_name     = var.domain_name
    zenml_namespace = var.zenml_namespace
  })
  depends_on = [helm_release.zenml]
}

# 12. Create ReferenceGrant to allow cross-namespace routing
resource "kubectl_manifest" "refgrant_zenml" {
  count     = var.enable_zenml ? 1 : 0
  yaml_body = templatefile("${path.module}/manifests/zenml-reference-grant.yaml", {
    zenml_namespace = var.zenml_namespace
  })
  depends_on = [helm_release.zenml]
}

# 13. Create ServiceMonitor for Prometheus
# This allows the existing Prometheus stack to automatically discover and scrape
# metrics from the ZenML server.
resource "kubectl_manifest" "zenml_servicemonitor" {
  count = var.enable_zenml && var.enable_prometheus_operator ? 1 : 0
  yaml_body = templatefile("${path.module}/manifests/zenml-service-monitor.yaml", {
    monitoring_namespace = var.monitoring_namespace
    zenml_namespace      = var.zenml_namespace
  })
  depends_on = [helm_release.zenml]
}

# 14. Update Kyverno policies to exclude zenml-system namespace
resource "kubectl_manifest" "kyverno_zenml_exclusion" {
  count = var.enable_zenml && var.enable_kyverno ? 1 : 0
  yaml_body = templatefile("${path.module}/manifests/kyverno-zenml-policy.yaml", {
    zenml_namespace = var.zenml_namespace
  })
}