# Terraform Execution Order

This document explains the order of execution for Terraform components in the project, how dependencies are managed, and the specific commands used in each step.

## Overview

The Terraform project deploys a complete Kubernetes infrastructure with the following components in sequence:

1. Civo Kubernetes Cluster with Cilium CNI
2. Cilium CNI configuration and upgrade
3. cert-manager for certificate management
4. Gateway API CRDs and Kgateway implementation
5. DNS configuration with Cloudflare
6. TLS certificates via Let's Encrypt
7. ArgoCD for GitOps

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

## 2. Certificate Management

### 2.1. cert-manager Namespace

**File:** `helm_cert_manager.tf`

```hcl
resource "kubernetes_namespace" "cert_manager" {
  metadata {
    name = "cert-manager"
  }
}
```

Creates the namespace for cert-manager. No explicit dependencies.

### 2.2. cert-manager Helm Release

**File:** `helm_cert_manager.tf`

```hcl
resource "helm_release" "cert_manager" {
  name       = "cert-manager"
  repository = "https://charts.jetstack.io"
  chart      = "cert-manager"
  namespace  = kubernetes_namespace.cert_manager.metadata[0].name
  version    = "v1.15.1"
  
  # Add timeout to prevent indefinite waiting
  timeout = 900  # 15 minutes
  
  # Set atomic to false to prevent rollback on timeout
  atomic = false

  set {
    name  = "installCRDs"
    value = "true"
  }

  depends_on = [
    kubernetes_namespace.cert_manager,
    null_resource.cilium_upgrade,  # Ensure Cilium is fully deployed first
    time_sleep.wait_for_cluster    # Ensure cluster is ready
  ]
}
```

This deploys cert-manager using Helm. It depends on:
- The cert-manager namespace
- Cilium upgrade completion
- Cluster readiness

### 2.3. Cloudflare API Token Secret

**File:** `kubernetes_cert_manager.tf`

```hcl
resource "kubernetes_secret" "cloudflare_api_token_secret" {
  metadata {
    name      = "cloudflare-api-token-secret"
    namespace = kubernetes_namespace.cert_manager.metadata[0].name
  }

  data = {
    "api-token" = var.cloudflare_api_token
  }

  type = "Opaque"

  depends_on = [
    helm_release.cert_manager,
    time_sleep.wait_for_cluster
  ]
}
```

Creates a Kubernetes secret with the Cloudflare API token for DNS validation. Depends on cert-manager deployment.

### 2.4. Let's Encrypt Staging Issuer

**File:** `kubernetes_cert_manager.tf`

```hcl
resource "kubectl_manifest" "letsencrypt_issuer" {
  yaml_body = <<-EOF
  apiVersion: cert-manager.io/v1
  kind: ClusterIssuer
  metadata:
    name: letsencrypt-staging
  spec:
    acme:
      server: https://acme-staging-v02.api.letsencrypt.org/directory
      email: ${var.cloudflare_email}
      privateKeySecretRef:
        name: letsencrypt-staging
      solvers:
      - dns01:
          cloudflare:
            email: ${var.cloudflare_email}
            apiTokenSecretRef:
              name: ${kubernetes_secret.cloudflare_api_token_secret.metadata[0].name}
              key: api-token
  EOF

  depends_on = [
    kubernetes_secret.cloudflare_api_token_secret,
  ]
}
```

Creates a ClusterIssuer for Let's Encrypt staging environment. Depends on the Cloudflare API token secret.

### 2.5. Let's Encrypt Production Issuer

**File:** `kubernetes_cert_manager.tf`

```hcl
resource "kubectl_manifest" "letsencrypt_prod_issuer" {
  yaml_body = <<-EOF
  apiVersion: cert-manager.io/v1
  kind: ClusterIssuer
  metadata:
    name: letsencrypt-prod
  spec:
    acme:
      server: https://acme-v02.api.letsencrypt.org/directory
      email: ${var.cloudflare_email}
      privateKeySecretRef:
        name: letsencrypt-prod
      solvers:
      - dns01:
          cloudflare:
            email: ${var.cloudflare_email}
            apiTokenSecretRef:
              name: ${kubernetes_secret.cloudflare_api_token_secret.metadata[0].name}
              key: api-token
  EOF

  depends_on = [
    kubernetes_secret.cloudflare_api_token_secret,
  ]
}
```

Creates a ClusterIssuer for Let's Encrypt production environment. Depends on the Cloudflare API token secret.

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
  version          = "v2.0.2"  # Latest stable release as per docs
  namespace        = "kgateway-system"
  create_namespace = true
  atomic           = false  # Set to false to prevent rollback on timeout
  cleanup_on_fail  = true
  wait             = true
  timeout          = 900    # 15 minutes

  depends_on = [
    helm_release.kgateway_crds,
    time_sleep.wait_for_kgateway_crds,
    helm_release.cert_manager  # Ensure cert-manager is deployed first
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

### 4.5. Gateway Certificate

**File:** `kgateway_certificate.tf`

```hcl
resource "kubectl_manifest" "gateway_certificate" {
  yaml_body = <<-YAML
  apiVersion: cert-manager.io/v1
  kind: Certificate
  metadata:
    name: default-gateway-cert
    namespace: default
  spec:
    secretName: default-gateway-cert
    issuerRef:
      name: letsencrypt-prod
      kind: ClusterIssuer
    dnsNames:
    - "*.${var.domain_name}"
  YAML

  depends_on = [
    kubectl_manifest.letsencrypt_prod_issuer,
    helm_release.cert_manager,
    cloudflare_dns_record.wildcard
  ]
}
```

Creates a wildcard certificate for the Gateway using cert-manager. Depends on:
- Let's Encrypt production issuer
- cert-manager deployment
- Wildcard DNS record

## 5. ArgoCD Deployment

### 5.1. ArgoCD Namespace

**File:** `helm_argocd.tf`

```hcl
resource "kubernetes_namespace" "argocd" {
  metadata {
    name = "argocd"
  }
}
```

Creates the namespace for ArgoCD. No explicit dependencies.

### 5.2. ArgoCD Helm Release

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
    helm_release.kgateway,  # Ensure Kgateway is deployed first
    helm_release.cert_manager  # Ensure cert-manager is deployed first
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
    kubectl_manifest.letsencrypt_issuer,
    kubectl_manifest.default_gateway_cert
  ]
}
```

Creates an HTTPRoute for ArgoCD to expose it through the Gateway. Depends on:
- ArgoCD deployment
- Default Gateway resource
- Let's Encrypt issuer
- Gateway certificate

## 6. Execution Order Summary

The complete execution order of the Terraform components is as follows:

1. **Cluster Infrastructure**
   - Civo Firewall
   - Civo Kubernetes Cluster
   - Kubeconfig Generation
   - Wait for Cluster Readiness (60s)

2. **Networking Layer**
   - Cilium CNI Upgrade

3. **Certificate Management**
   - cert-manager Namespace
   - cert-manager Helm Release
   - Cloudflare API Token Secret
   - Let's Encrypt Staging Issuer
   - Let's Encrypt Production Issuer

4. **Gateway API and Kgateway**
   - Gateway API CRDs
   - Wait for Gateway API CRDs (30s)
   - Kgateway CRDs
   - Wait for Kgateway CRDs (30s)
   - Kgateway Helm Release
   - Default Gateway Resource
   - Wait for Gateway Load Balancer (30s)

5. **DNS and Certificate Configuration**
   - Root Domain DNS Record
   - Wildcard DNS Record
   - Gateway Certificate

6. **GitOps Platform**
   - ArgoCD Namespace
   - ArgoCD Helm Release
   - ArgoCD HTTPRoute

## 7. Architecture Evolution Path

This execution order establishes the foundation for the architecture evolution goals:

1. **Current Implementation**
   - Cilium CNI for networking and network policies
   - Gateway API with Kgateway for general ingress/web traffic
   - ArgoCD for GitOps-based application deployment

2. **Future Components** (not yet implemented)
   - Dapr for application building-blocks
   - Specialized AI Gateway for LLM traffic
   - Ambient Mesh for east-west mTLS, retries, and telemetry

The current implementation provides a solid foundation with proper sequencing and dependency management for the future evolution of the architecture.
