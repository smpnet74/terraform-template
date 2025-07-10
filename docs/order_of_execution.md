# Terraform Execution Order

This document explains the order of execution for Terraform components in the project, how dependencies are managed, and the specific commands used in each step.

## Overview

The Terraform project deploys a complete Kubernetes infrastructure with the following components in sequence:

1. Civo Kubernetes Cluster with Cilium CNI
2. Cilium CNI configuration and upgrade
3. Gateway API CRDs and Kgateway implementation
4. Cloudflare Origin Certificates for TLS
5. DNS configuration with Cloudflare (proxied)
6. Gloo Operator and Ambient Mesh installation
7. ArgoCD for GitOps
8. Argo Workflows for CI/CD (optional)

## 1. Cluster Creation and Initial Setup

### 1.1. Civo Firewall

**File:** `civo_firewall-cluster.tf`

```hcl
resource "civo_firewall" "firewall" {
  name               = "${var.cluster_name_prefix}firewall-new"
  create_default_rules = false
  
  ingress_rule {
    label      = "kubernetes-api-server"
    protocol   = "tcp"
    port_range = "6443"
    cidr       = var.allowed_ips
    action     = "allow"
  }
}
```

This creates the firewall rules for the Kubernetes cluster. No explicit dependencies.

### 1.2. Kubernetes Cluster

**File:** `cluster.tf`

```hcl
resource "civo_kubernetes_cluster" "cluster" {
  name        = "${var.cluster_name_prefix}cluster"
  firewall_id = civo_firewall.firewall.id
  cni         = "cilium"
  pools {
    node_count = var.cluster_node_count
    size       = var.cluster_node_size
  }
  timeouts {
    create = "5m"
  }
}
```

The cluster depends on the firewall through the `firewall_id` reference.

### 1.3. Kubeconfig Generation

**File:** `cluster.tf`

```hcl
resource "local_file" "cluster-config" {
  content              = civo_kubernetes_cluster.cluster.kubeconfig
  filename             = "${path.module}/kubeconfig"
  file_permission      = "0600"
  directory_permission = "0755"
}
```

This generates the kubeconfig file needed for subsequent kubectl and Helm operations. It depends on the cluster through the `civo_kubernetes_cluster.cluster.kubeconfig` reference.

### 1.4. Wait for Cluster Readiness

**File:** `cluster_ready_delay.tf`

```hcl
resource "time_sleep" "wait_for_cluster" {
  depends_on = [
    civo_kubernetes_cluster.cluster,
    local_file.cluster-config
  ]
  
  create_duration = "60s"
}
```

This adds a 60-second delay after cluster creation to ensure the API server is fully ready before proceeding with other resources.

### 1.5. Cilium CNI Upgrade

**File:** `helm_cilium.tf`

```hcl
resource "null_resource" "cilium_upgrade" {
  triggers = {
    cilium_version = "1.17.5"
  }

  depends_on = [
    civo_kubernetes_cluster.cluster
  ]

  provisioner "local-exec" {
    command = <<-EOT
      # Add Cilium Helm repository
      helm repo add cilium https://helm.cilium.io
      helm repo update
      
      # Create values file with proper configuration
      cat > cilium_values.yaml <<EOF
      # ... Cilium values ...
      EOF
      
      # Upgrade Cilium using Helm
      helm upgrade cilium cilium/cilium \
        --version 1.17.5 \
        --namespace kube-system \
        --reset-values \
        --reuse-values \
        --values cilium_values.yaml \
        --kubeconfig ${path.module}/kubeconfig
    EOT
  }
}
```

This upgrades the Cilium CNI with specific configuration values. It depends on the cluster creation through the explicit `depends_on` attribute.

## 2. TLS Certificate Management

### 2.1. Cloudflare Origin Certificate

**File:** `kgateway_certificate.tf`

```hcl
resource "kubernetes_secret" "cloudflare_origin_cert" {
  metadata {
    name      = "default-gateway-cert"
    namespace = "default"
  }

  type = "kubernetes.io/tls"

  data = {
    "tls.crt" = file("${path.module}/certs/tls.crt")
    "tls.key" = file("${path.module}/certs/tls.key")
  }

  depends_on = [
    civo_kubernetes_cluster.cluster,
    time_sleep.wait_for_cluster
  ]
}
```

This creates a Kubernetes TLS secret containing the Cloudflare Origin Certificate. The certificate files (`tls.crt` and `tls.key`) are stored locally in the `/certs` directory and are not committed to Git. This certificate is used by the Gateway for TLS termination.

The secret depends on:
- Cluster creation
- Cluster readiness

## 3. Gateway API and Kgateway

### 3.1. Gateway API CRDs

**File:** `kgateway_api.tf`

```hcl
resource "null_resource" "gateway_api_crds" {
  provisioner "local-exec" {
    command = <<-EOT
      # Install Gateway API CRDs v1.2.1 (as per official docs)
      kubectl --kubeconfig ${path.module}/kubeconfig apply -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.2.1/standard-install.yaml
    EOT
  }

  depends_on = [
    civo_kubernetes_cluster.cluster,
    time_sleep.wait_for_cluster,
    null_resource.cilium_upgrade  # Ensure Cilium is installed first
  ]
}
```

Installs the Gateway API CRDs. Depends on:
- Cluster creation
- Cluster readiness
- Cilium upgrade completion

### 3.2. Wait for Gateway API CRDs

**File:** `kgateway_api.tf`

```hcl
resource "time_sleep" "wait_for_gateway_crds" {
  depends_on = [null_resource.gateway_api_crds]
  create_duration = "30s"
}
```

Adds a 30-second delay after Gateway API CRDs installation to ensure they are established.

### 3.3. Kgateway CRDs

**File:** `kgateway_api.tf`

```hcl
resource "helm_release" "kgateway_crds" {
  name             = "kgateway-crds"
  repository       = "" # Using OCI registry instead of traditional Helm repo
  chart            = "oci://cr.kgateway.dev/kgateway-dev/charts/kgateway-crds"
  version          = "v2.0.2"  # Latest stable release as per docs
  namespace        = "kgateway-system"
  create_namespace = true
  atomic           = true
  cleanup_on_fail  = true
  wait             = true

  depends_on = [
    null_resource.gateway_api_crds,
    time_sleep.wait_for_gateway_crds
  ]
}
```

Installs the Kgateway CRDs using Helm. Depends on Gateway API CRDs installation and the wait period.

### 3.4. Wait for Kgateway CRDs

**File:** `kgateway_api.tf`

```hcl
resource "time_sleep" "wait_for_kgateway_crds" {
  depends_on = [helm_release.kgateway_crds]
  create_duration = "30s"
}
```

Adds a 30-second delay after Kgateway CRDs installation to ensure they are established.

### 3.5. Kgateway Helm Release

**File:** `kgateway_api.tf`

```hcl
resource "helm_release" "kgateway" {
  name             = "kgateway"
  repository       = "" # Using OCI registry instead of traditional Helm repo
  chart            = "oci://cr.kgateway.dev/kgateway-dev/charts/kgateway"
  version          = "v2.0.3"  # Updated to latest stable release
  namespace        = "kgateway-system"
  create_namespace = true
  atomic           = false  # Set to false to prevent rollback on timeout
  cleanup_on_fail  = true
  wait             = true
  timeout          = 900    # 15 minutes

  depends_on = [
    helm_release.kgateway_crds,
    time_sleep.wait_for_kgateway_crds
  ]
}
```

Deploys Kgateway using Helm. Depends on:
- Kgateway CRDs installation
- Wait period after CRDs installation
- cert-manager deployment

### 3.6. Default Gateway Resource

**File:** `kgateway_api.tf`

```hcl
resource "kubectl_manifest" "default_gateway" {
  yaml_body = <<-YAML
  apiVersion: gateway.networking.k8s.io/v1
  kind: Gateway
  metadata:
    name: default-gateway
    namespace: default
  spec:
    gatewayClassName: kgateway
    listeners:
    - name: http
      port: 80
      protocol: HTTP
      allowedRoutes:
        namespaces:
          from: All
    - name: https
      port: 443
      protocol: HTTPS
      allowedRoutes:
        namespaces:
          from: All
      tls:
        mode: Terminate
        certificateRefs:
        - name: default-gateway-cert
          kind: Secret
          group: ""
  YAML

  depends_on = [
    helm_release.kgateway
  ]
}
```

Creates the default Gateway resource that handles all ingress traffic. Depends on the Kgateway deployment.

## 4. DNS and Certificate Configuration

### 4.1. Gateway Load Balancer Service

**File:** `cloudflare_dns.tf`

```hcl
data "kubernetes_service" "gateway_lb" {
  metadata {
    name      = "default-gateway"
    namespace = "default"
  }
  depends_on = [kubectl_manifest.default_gateway]
}

# Use a local value to safely handle the IP address with a fallback
locals {
  # Check if the gateway service has a load balancer IP assigned
  gateway_lb_ip = try(
    data.kubernetes_service.gateway_lb.status[0].load_balancer[0].ingress[0].ip,
    "192.0.2.1" # Fallback to a placeholder IP (TEST-NET-1 from RFC 5737)
  )
}
```

Retrieves the external IP address of the Gateway load balancer service. Depends on the default Gateway resource.

### 4.2. Wait for Gateway Load Balancer

**File:** `cloudflare_dns.tf`

```hcl
resource "time_sleep" "wait_for_gateway_lb" {
  depends_on = [kubectl_manifest.default_gateway]
  create_duration = "30s"
}
```

Adds a 30-second delay after Gateway creation to ensure the load balancer service is fully ready.

### 4.3. Root Domain DNS Record

**File:** `cloudflare_dns.tf`

```hcl
resource "cloudflare_dns_record" "root" {
  zone_id = var.cloudflare_zone_id
  name    = var.domain_name
  content = local.gateway_lb_ip
  type    = "A"
  proxied = false
  ttl     = 1 # Automatic
  depends_on = [time_sleep.wait_for_gateway_lb]
}
```

Creates an A record for the root domain pointing to the Gateway IP. Depends on the wait period after Gateway creation.

### 4.4. Wildcard DNS Record

**File:** `cloudflare_dns.tf`

```hcl
resource "cloudflare_dns_record" "wildcard" {
  zone_id = var.cloudflare_zone_id
  name    = "*"
  content = local.gateway_lb_ip  # Point directly to Gateway IP
  type    = "A"                 # Change to A record
  proxied = false
  ttl     = 1 # Automatic
  depends_on = [time_sleep.wait_for_gateway_lb]
}
```

Creates a wildcard A record for all subdomains pointing to the Gateway IP. Depends on the wait period after Gateway creation.

### 4.5. Cloudflare DNS Proxy Configuration

**File:** `cloudflare_dns.tf`

```hcl
resource "cloudflare_record" "root" {
  zone_id = var.cloudflare_zone_id
  name    = var.domain_name
  content = local.gateway_lb_ip
  type    = "A"
  proxied = true  # Enable Cloudflare proxy (orange cloud)
  ttl     = 1     # Automatic
  depends_on = [time_sleep.wait_for_gateway_lb]
}

resource "cloudflare_record" "wildcard" {
  zone_id = var.cloudflare_zone_id
  name    = "*"
  content = local.gateway_lb_ip
  type    = "A"
  proxied = true  # Enable Cloudflare proxy (orange cloud)
  ttl     = 1     # Automatic
  depends_on = [time_sleep.wait_for_gateway_lb]
}
```

Configures Cloudflare DNS records with proxying enabled (orange cloud). This provides:
- DDoS protection
- TLS termination at Cloudflare edge
- Connection to the cluster using Cloudflare Origin Certificate

The Cloudflare SSL/TLS settings should be configured to use "Full" mode to ensure encrypted traffic between Cloudflare and the cluster.

## 5. Gloo Operator and Ambient Mesh Installation

### 5.1. Gloo Operator Namespace

**File:** `helm_gloo_operator.tf`

```hcl
resource "kubernetes_namespace" "gloo_operator" {
  metadata {
    name = "gloo-operator"
  }

  depends_on = [
    civo_kubernetes_cluster.cluster,
    time_sleep.wait_for_cluster
  ]
}
```

Creates the namespace for Gloo Operator. Depends on cluster creation and readiness.

### 5.2. Gloo Operator Helm Release

**File:** `helm_gloo_operator.tf`

```hcl
resource "helm_release" "gloo_operator" {
  name       = "gloo-operator"
  repository = ""  # Using OCI registry
  chart      = "oci://us-docker.pkg.dev/solo-public/gloo-operator-helm/gloo-operator"
  namespace  = kubernetes_namespace.gloo_operator.metadata[0].name
  
  # Set atomic to false to prevent rollback on timeout
  atomic = false
  
  # Add timeout to prevent indefinite waiting
  timeout = 900  # 15 minutes
  
  depends_on = [
    kubernetes_namespace.gloo_operator,
    null_resource.cilium_upgrade  # Ensure Cilium is fully deployed first with cni.exclusive: false
  ]
}
```

Installs the Gloo Operator using Helm. Depends on the Gloo Operator namespace and Cilium upgrade completion.

### 5.3. Wait for Gloo Operator

**File:** `helm_gloo_operator.tf`

```hcl
resource "time_sleep" "wait_for_gloo_operator" {
  depends_on = [helm_release.gloo_operator]
  create_duration = "30s"
}
```

Adds a 30-second delay after Gloo Operator installation to ensure it is fully ready.

### 5.4. ServiceMeshController Resource

**File:** `helm_gloo_operator.tf`

```hcl
resource "kubectl_manifest" "service_mesh_controller" {
  yaml_body = <<-EOF
    apiVersion: operator.gloo.solo.io/v1
    kind: ServiceMeshController
    metadata:
      name: managed-istio
      labels:
        app.kubernetes.io/name: managed-istio
    spec:
      dataplaneMode: Ambient
      installNamespace: istio-system
      version: 1.26.2
      # Additional configuration for Cilium compatibility
      values:
        pilot:
          env:
            PILOT_ENABLE_AMBIENT: "true"
        cni:
          enabled: true
          chained: true
          ambient: true
          cniBinDir: "/opt/cni/bin"
          cniConfDir: "/etc/cni/net.d"
        ambient:
          redirectMode: ebpf
        meshConfig:
          defaultConfig:
            interceptionMode: NONE
  EOF

  depends_on = [
    helm_release.gloo_operator,
    time_sleep.wait_for_gloo_operator
  ]
}
```

Creates a ServiceMeshController resource that instructs the Gloo Operator to install Istio with Ambient Mesh mode. The configuration includes specific settings for compatibility with Cilium CNI:

- `PILOT_ENABLE_AMBIENT: "true"` - Enables Ambient Mesh mode in istiod
- `cni.chained: true` - Configures Istio CNI as a chained plugin alongside Cilium
- `cni.ambient: true` - Enables Ambient Mesh support in the CNI
- `ambient.redirectMode: ebpf` - Uses eBPF for traffic redirection in ztunnel
- `interceptionMode: NONE` - Uses external CNI instead of Istio's own CNI

Depends on the Gloo Operator installation and the wait period.

### 5.5. Wait for ServiceMeshController

**File:** `helm_gloo_operator.tf`

```hcl
resource "time_sleep" "wait_for_service_mesh_controller" {
  depends_on = [kubectl_manifest.service_mesh_controller]
  create_duration = "120s"  # Allow more time for Istio components to be deployed
}
```

Adds a 120-second delay after ServiceMeshController creation to allow time for all Istio components (istio-base, istio-cni, istiod, and ztunnel) to be deployed.

## 6. ArgoCD Deployment

### 6.1. ArgoCD Namespace

**File:** `helm_argocd.tf`

```hcl
resource "kubernetes_namespace" "argocd" {
  metadata {
    name = "argocd"
  }
}
```

Creates the namespace for ArgoCD. No explicit dependencies.

### 6.2. ArgoCD Helm Release

**File:** `helm_argocd.tf`

```hcl
resource "helm_release" "argocd" {
  name       = "argocd"
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-cd"
  namespace  = kubernetes_namespace.argocd.metadata[0].name
  version    = "7.3.8"

  wait    = true
  atomic  = false  # Set to false to prevent rollback on timeout
  timeout = 900    # 15 minutes

  # The key insight: server.insecure must be set as an extraArg with empty string value
  # And the URL must be set in the ConfigMap (cm) section
  values = [
    <<-EOF
    server:
      extraArgs:
        - --insecure

    configs:
      cm:
        url: https://argocd.${var.domain_name}
    EOF
  ]

  depends_on = [
    kubernetes_namespace.argocd,
    helm_release.kgateway  # Ensure Kgateway is deployed first
  ]
}
```

Deploys ArgoCD using Helm. Depends on:
- ArgoCD namespace
- Kgateway deployment
- cert-manager deployment

### 5.3. ArgoCD HTTPRoute

**File:** `kubernetes_ingress-argocd.tf`

```hcl
resource "kubectl_manifest" "argocd_httproute" {
  yaml_body = <<-YAML
  apiVersion: gateway.networking.k8s.io/v1
  kind: HTTPRoute
  metadata:
    name: argocd-server-route
    namespace: argocd
  spec:
    parentRefs:
    - name: default-gateway
      namespace: default
      kind: Gateway
    hostnames:
    - "test-argocd.${var.domain_name}"
    rules:
    - matches:
      - path:
          type: PathPrefix
          value: /
      backendRefs:
      - name: argocd-server
        port: 80
  YAML

  depends_on = [
    helm_release.argocd,
    kubectl_manifest.default_gateway,
    kubernetes_secret.cloudflare_origin_cert
  ]
}
```

Creates an HTTPRoute for ArgoCD to expose it through the Gateway. Depends on:
- ArgoCD deployment
- Default Gateway resource
- Let's Encrypt issuer
- Gateway certificate

## 7. Argo Workflows Deployment (Optional)

### 7.1. Argo Workflows Helm Release

**File:** `argo_workflows.tf`

```hcl
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
```

Deploys Argo Workflows for in-cluster CI/CD capabilities. Depends on cluster readiness.

### 7.2. Argo Events Helm Release

**File:** `argo_workflows.tf`

```hcl
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
```

Deploys Argo Events for EventSources and Sensors. Depends on Argo Workflows deployment.

### 7.3. EventBus Configuration

**File:** `argo_workflows.tf`

```hcl
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
```

Creates an EventBus for event communication between EventSources and Sensors.

### 7.4. Argo Workflows HTTPRoute

**File:** `argo_workflows.tf`

```hcl
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
```

Exposes Argo Workflows server through the Gateway for web UI access.

### 7.5. ReferenceGrant for Cross-Namespace Access

**File:** `argo_workflows.tf`

```hcl
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
```

Allows HTTPRoute in the `argo` namespace to reference the Gateway in the `default` namespace.

## 8. Execution Order Summary

The complete execution order of the Terraform components is as follows:

1. **Cluster Infrastructure**
   - Civo Firewall
   - Civo Kubernetes Cluster (version 1.30.5-k3s1)
   - Kubeconfig Generation
   - Wait for Cluster Readiness (60s)

2. **Networking Layer**
   - Cilium CNI Upgrade (version 1.17.5 with cni.exclusive: false for Ambient Mesh compatibility)

3. **TLS Certificate Management**
   - Cloudflare Origin Certificate Secret

4. **Gateway API and Kgateway**
   - Gateway API CRDs (v1.2.1)
   - Wait for Gateway API CRDs (30s)
   - Kgateway CRDs (v2.0.3)
   - Wait for Kgateway CRDs (30s)
   - Kgateway Helm Release (v2.0.3)
   - Default Gateway Resource (using Cloudflare Origin Certificate)
   - Wait for Gateway Load Balancer (30s)

5. **DNS and Certificate Configuration**
   - Root Domain DNS Record (proxied through Cloudflare)
   - Wildcard DNS Record (proxied through Cloudflare)
   - Cloudflare SSL/TLS settings (Full mode)

6. **GitOps Platform**
   - ArgoCD Namespace
   - ArgoCD Helm Release
   - ArgoCD HTTPRoute

7. **CI/CD Platform (Optional)**
   - Argo Workflows Helm Release (v0.45.19 - Argo Workflows 3.6.10)
   - Argo Events Helm Release (v2.4.15 - compatible with Argo Workflows 3.6.10)
   - EventBus Configuration (JetStream-based event communication)
   - Argo Workflows HTTPRoute
   - ReferenceGrant for cross-namespace access

## 8. Architecture Evolution Path

This execution order establishes the foundation for the architecture evolution goals:

1. **Current Implementation**
   - Kubernetes 1.30.5-k3s1 for modern Kubernetes features
   - Cilium CNI 1.17.5 for networking and network policies (with cni.exclusive: false for Ambient Mesh compatibility)
   - Gateway API v1.2.1 with Kgateway v2.0.3 for general ingress/web traffic
   - Cloudflare Origin Certificates for TLS termination
   - Cloudflare proxying for DDoS protection and edge TLS
   - ArgoCD for GitOps-based application deployment

2. **Future Components** (prepared for implementation)
   - Dapr for application building-blocks
   - Specialized AI Gateway for LLM traffic (using Gateway API)
   - Istio Ambient Mesh for east-west mTLS, retries, and telemetry with the following configuration:
     - Istio CNI node agent with chained plugin alongside Cilium
     - cni.chained=true to work alongside Cilium
     - cni.ambient=true to enable Ambient Mesh support
     - ambient.redirectMode=ebpf for ztunnel
     - Installation order: istio-base → istio-cni → istiod → ztunnel
     - PILOT_ENABLE_AMBIENT=true environment variable for istiod

The current implementation provides a solid foundation with proper sequencing and dependency management for the future evolution of the architecture. The Kubernetes version and Cilium configuration have been specifically prepared to ensure compatibility with Istio Ambient Mesh.
