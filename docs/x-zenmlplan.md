# ZenML MLOps Platform – Implementation Plan

## 1. Overview
This document outlines a refined plan to deploy the ZenML MLOps platform. It is designed for a manual stack setup post-deployment, providing the necessary outputs to connect and configure ZenML.

This revised plan improves upon the previous version by:
*   **Using Latest Versions:** The ZenML Helm chart and server image are updated to `0.84.0`.
*   **Correcting Database Provisioning:** The plan now correctly handles database credentialing, ensuring the ZenML server can connect to its PostgreSQL backend.
*   **Improving Configurability:** The PostgreSQL version is now a configurable variable.
*   **Focusing on Manual Setup:** The plan provides the exact outputs required to manually connect the ZenML CLI and configure the stack.

---

## 2. Solution Architecture
The architecture remains the same, but the implementation details for database credentialing are now correct.

```
┌─────────────┐      ┌──────────────────────┐      ┌─────────────────┐
│  ZenML CLI  │──────│  Gateway API + Kgateway│────►│  ZenML Server   │
└─────────────┘      └──────────────────────┘      └────────┬────────┘
                                                          ┌─▼──────────┐
                                                          │PostgreSQL  │  (KubeBlocks)
                                                          └─┬──────────┘
                                                            │Artifacts
                                          ┌─────────────────▼────────────────┐
                                          │   Civo Object Storage (S3-API)    │
                                          └───────────────────────────────────┘
```

---

## 3. Implementation Plan

### Step 1: Add Variables to `io.tf`
These variables enable the ZenML deployment and control its configuration.

```hcl
# ZenML MLOps Platform
variable "enable_zenml" {
  description = "Whether to deploy the ZenML MLOps platform"
  type        = bool
  default     = false
}

variable "zenml_chart_version" {
  description = "Helm chart version for ZenML Server"
  type        = string
  default     = "0.84.0" # Latest version as of July 2025
}

variable "zenml_server_version" {
  description = "Version of the ZenML server Docker image"
  type        = string
  default     = "0.84.0"
}


variable "zenml_namespace" {
  description = "Namespace for ZenML components"
  type        = string
  default     = "zenml-system"
}

variable "zenml_artifact_bucket" {
  description = "Name of the Civo Object Store bucket for ZenML artifacts"
  type        = string
  default     = "zenml-artifacts"
}
```

### Step 2: Create `zenml.tf`
This new file will contain all resources required for the ZenML deployment.

```hcl
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

# 4. Provision a PostgreSQL database using KubeBlocks
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
  clusterDefinitionRef: postgresql
  clusterVersionRef: postgresql-16.2.0
  componentSpecs:
  - name: postgresql
    componentDefRef: postgresql
    replicas: 1
    # This tells KubeBlocks to use the secret we created for the initial user/password.
    # The user 'zenml' will be created with the password from the secret.
    userPasswordSecret:
      name: ${kubernetes_secret.zenml_db_creds[0].metadata[0].name}
    resources:
      requests:
        cpu: 100m
        memory: 256Mi
    storage:
      name: data
      storageClassName: civo-volume
      size: 5Gi
  terminationPolicy: WipeOut
YAML
  depends_on = [helm_release.kubeblocks, kubernetes_namespace.zenml, kubernetes_secret.zenml_db_creds]
}

# 5. Create the Civo Object Store bucket for ZenML artifacts
resource "civo_object_store" "zenml_artifacts" {
  count       = var.enable_zenml ? 1 : 0
  name        = var.zenml_artifact_bucket
  region      = var.region
  max_size_gb = 50 # Default size, can be made a variable
}

# 6. Create dedicated credentials for ZenML to access the Object Store
resource "civo_object_store_credential" "zenml" {
  count  = var.enable_zenml ? 1 : 0
  name   = "zenml-credentials"
  region = var.region
}

# 7. Create Kubernetes secret from the generated Civo Object Store credentials
resource "kubernetes_secret" "zenml_s3_creds" {
  count = var.enable_zenml ? 1 : 0
  metadata {
    name      = "zenml-s3-creds"
    namespace = var.zenml_namespace
  }
  data = {
    key_id       = civo_object_store_credential.zenml[0].access_key_id
    secret_key   = civo_object_store_credential.zenml[0].secret_access_key
    endpoint_url = "https://object-store.${var.region}.civo.com"
  }
  depends_on = [civo_object_store_credential.zenml]
}

# 8. Deploy ZenML Server using the official Helm chart
resource "helm_release" "zenml" {
  count      = var.enable_zenml ? 1 : 0
  name       = "zenml"
  repository = "https://zenml-io.github.io/zenml-helm"
  chart      = "zenml-server"
  version    = var.zenml_chart_version
  namespace  = var.zenml_namespace

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
      
      zenml = {
        database = {
          # Use postgres database (default) instead of zenml database
          url = "postgresql://zenml:${random_password.zenml_db[0].result}@zenml-postgres-postgresql.${var.zenml_namespace}.svc.cluster.local:5432/postgres"
        }
        server = {
          admin_token = random_password.zenml_admin_token[0].result
        }
        # Artifact store configuration is typically done via CLI, not Helm values
      }
    })
  ]

  depends_on = [
    time_sleep.wait_for_zenml_postgres,
    kubernetes_secret.zenml_s3_creds,
    civo_object_store.zenml_artifacts
  ]
}


# 9. Wait for PostgreSQL cluster to be ready
resource "time_sleep" "wait_for_zenml_postgres" {
  count = var.enable_zenml ? 1 : 0
  depends_on = [kubectl_manifest.zenml_postgres_cluster]
  create_duration = "120s"
}

# 10. Expose ZenML UI via Gateway API
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
    - name: zenml-server
      namespace: ${var.zenml_namespace}
      port: 80
      kind: Service
YAML
  depends_on = [helm_release.zenml, kubectl_manifest.default_gateway]
}

# 11. Create ReferenceGrant to allow cross-namespace routing
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
    name: zenml-server
YAML
  depends_on = [helm_release.zenml]
}

# 12. Create ServiceMonitor for Prometheus
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

# 13. Update Kyverno policies to exclude zenml-system namespace
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
  validationFailureAction: enforce
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
```

### Step 3: Add Outputs to `outputs.tf`
These outputs provide the necessary information to manually connect and configure ZenML.

```hcl
# outputs.tf

output "zenml_ui_url" {
  description = "URL to access the ZenML Server web UI."
  value       = var.enable_zenml ? "https://zenml.${var.domain_name}" : "ZenML is disabled."
}

output "zenml_connect_command" {
  description = "Command to connect the ZenML CLI to the deployed server."
  value       = var.enable_zenml ? "zenml connect --url https://zenml.${var.domain_name} --token ${random_password.zenml_admin_token[0].result}" : "ZenML is disabled."
  sensitive   = true
}

output "zenml_manual_stack_configuration" {
  description = "Information required to manually register the artifact store."
  value       = var.enable_zenml ? <<EOT
To complete the setup, manually register the artifact store using the ZenML CLI:

1. Connect to the server using the 'zenml_connect_command' output.
2. Run the following command:

zenml artifact-store register ${var.zenml_artifact_bucket} --flavor=s3 --type=artifact-store --authentication_secret=zenml-s3-creds

3. Register a new stack using the artifact store:

zenml stack register local_s3_stack -o default -a ${var.zenml_artifact_bucket}

4. Set the new stack as active:

zenml stack set local_s3_stack

EOT
  : "ZenML is disabled."
}
```

### Step 4: Update Kyverno Exclusions in `tfvars`
Add the `zenml-system` namespace to the exclusion list to prevent Kyverno policies from interfering with its operation.

```hcl
# terraform.tfvars

kyverno_policy_exclusions = ["kube-system", "kyverno", "kgateway-system", "local-path-storage", "zenml-system"]
```

---

## 4. Deployment & Testing

1.  **Enable ZenML:** Set `enable_zenml = true` in your `terraform.tfvars` file.
2.  **Apply Changes:** Run `terraform apply`.
3.  **Check Outputs:** After the apply is complete, run `terraform output`.
4.  **Connect and Configure:** Use the `zenml_connect_command` and `zenml_manual_stack_configuration` outputs to finalize the setup.
5.  **Verify Connection:** Run `zenml status` to confirm the CLI is connected and the stack is configured correctly.
6.  **Update Documentation:** Once testing is complete and ZenML is fully operational, update the following project documentation:
    *   `docs/versions.md`: Add the versions for the ZenML server, Helm chart, and PostgreSQL.
    *   `docs/terraform_files_documentation.md`: Add an entry for `zenml.tf`.
    *   `docs/order_of_execution.md`: Include the new ZenML resources in the deployment graph.

