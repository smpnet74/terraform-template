# Gateway API and Kgateway Implementation

# Install Gateway API CRDs separately
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

# Wait for Gateway API CRDs to be established
resource "time_sleep" "wait_for_gateway_crds" {
  depends_on = [null_resource.gateway_api_crds]
  create_duration = "30s"
}

# Install Kgateway CRDs using Helm (as per official docs)
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

# Wait for Kgateway CRDs to be established
resource "time_sleep" "wait_for_kgateway_crds" {
  depends_on = [helm_release.kgateway_crds]
  create_duration = "30s"
}

# Install Kgateway using Helm
resource "helm_release" "kgateway" {
  name             = "kgateway"
  repository       = "" # Using OCI registry instead of traditional Helm repo
  chart            = "oci://cr.kgateway.dev/kgateway-dev/charts/kgateway"
  version          = "v2.0.2"  # Latest stable release as per docs
  namespace        = "kgateway-system"
  create_namespace = true
  atomic           = true
  cleanup_on_fail  = true
  wait             = true

  depends_on = [
    helm_release.kgateway_crds,
    time_sleep.wait_for_kgateway_crds
  ]
}

# Create a default Gateway resource
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

# Create a default certificate for the Gateway using cert-manager
resource "kubectl_manifest" "default_gateway_cert" {
  yaml_body = <<-YAML
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: default-gateway-cert
  namespace: default
spec:
  secretName: default-gateway-cert
  issuerRef:
    name: letsencrypt-staging
    kind: ClusterIssuer
  dnsNames:
  - "*.${var.domain_name}"
  - "${var.domain_name}"
  YAML

  depends_on = [
    kubectl_manifest.letsencrypt_issuer
  ]
}
