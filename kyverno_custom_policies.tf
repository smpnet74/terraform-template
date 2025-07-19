# Custom Kyverno Policies for Cluster-Specific Governance

# Gateway API HTTPRoute Validation Policy
resource "kubectl_manifest" "kyverno_gateway_api_httproute_policy" {
  count = var.enable_kyverno ? 1 : 0
  yaml_body = <<-YAML
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: gateway-api-httproute-standards
  annotations:
    policies.kyverno.io/title: Gateway API HTTPRoute Standards
    policies.kyverno.io/category: Gateway API
    policies.kyverno.io/severity: medium
    policies.kyverno.io/subject: HTTPRoute
    policies.kyverno.io/description: >-
      Ensures HTTPRoute resources follow organizational standards including
      proper Gateway references and hostname conventions.
spec:
  validationFailureAction: enforce
  background: true
  rules:
  - name: require-default-gateway-reference
    match:
      any:
      - resources:
          kinds:
          - HTTPRoute
    validate:
      message: "HTTPRoute must reference the default-gateway"
      pattern:
        spec:
          parentRefs:
          - name: default-gateway
            namespace: default
            kind: Gateway
  - name: require-domain-suffix
    match:
      any:
      - resources:
          kinds:
          - HTTPRoute
    validate:
      message: "HTTPRoute hostnames must use the configured domain"
      pattern:
        spec:
          hostnames:
          - "*.${var.domain_name}"
YAML

  depends_on = [
    null_resource.verify_kyverno_webhooks,  # Wait for webhooks to be ready
    kubectl_manifest.default_gateway       # Gateway must exist for HTTPRoute validation
  ]
}

# Cilium Network Policy Governance
resource "kubectl_manifest" "kyverno_cilium_networkpolicy_governance" {
  count = var.enable_kyverno ? 1 : 0
  yaml_body = <<-YAML
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: cilium-networkpolicy-governance
  annotations:
    policies.kyverno.io/title: Cilium Network Policy Governance
    policies.kyverno.io/category: Cilium
    policies.kyverno.io/severity: high
    policies.kyverno.io/subject: CiliumNetworkPolicy
    policies.kyverno.io/description: >-
      Ensures CiliumNetworkPolicy resources include required annotations
      and follow security best practices.
spec:
  validationFailureAction: enforce
  background: true
  rules:
  - name: require-policy-annotations
    match:
      any:
      - resources:
          kinds:
          - CiliumNetworkPolicy
    validate:
      message: "CiliumNetworkPolicy must include owner and purpose annotations"
      pattern:
        metadata:
          annotations:
            "policy.cilium.io/owner": "?*"
            "policy.cilium.io/purpose": "?*"
  - name: require-specific-rules
    match:
      any:
      - resources:
          kinds:
          - CiliumNetworkPolicy
    validate:
      message: "CiliumNetworkPolicy must specify explicit ingress or egress rules (empty rules create allow-all policies)"
      anyPattern:
      - spec:
          ingress:
          - "?*"  # At least one ingress rule must be specified
      - spec:
          egress:
          - "?*"  # At least one egress rule must be specified
      - spec:
          ingressDeny:
          - "?*"  # Or explicit deny rules
      - spec:
          egressDeny:
          - "?*"  # Or explicit deny rules
YAML

  depends_on = [
    null_resource.verify_kyverno_webhooks  # Wait for webhooks to be ready
  ]
}

# Istio Ambient Mesh Preparation Policy
resource "kubectl_manifest" "kyverno_istio_ambient_preparation" {
  count = var.enable_kyverno ? 1 : 0
  yaml_body = <<-YAML
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: istio-ambient-mesh-preparation
  annotations:
    policies.kyverno.io/title: Istio Ambient Mesh Preparation
    policies.kyverno.io/category: Istio
    policies.kyverno.io/severity: medium
    policies.kyverno.io/subject: Namespace
    policies.kyverno.io/description: >-
      Automatically adds ambient mesh labels to namespaces when they
      are annotated for ambient mesh inclusion.
spec:
  validationFailureAction: enforce
  background: true
  rules:
  - name: add-ambient-mode-label
    match:
      any:
      - resources:
          kinds:
          - Namespace
    mutate:
      patchStrategicMerge:
        metadata:
          labels:
            +(istio.io/dataplane-mode): ambient
    preconditions:
      any:
      - key: "{{ request.object.metadata.annotations.\"mesh.istio.io/ambient\" || '' }}"
        operator: Equals
        value: "enabled"
YAML

  depends_on = [
    null_resource.verify_kyverno_webhooks  # Wait for webhooks to be ready
  ]
}

# Cloudflare Certificate Policy
resource "kubectl_manifest" "kyverno_cloudflare_certificate_policy" {
  count = var.enable_kyverno ? 1 : 0
  yaml_body = <<-YAML
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: cloudflare-certificate-standards
  annotations:
    policies.kyverno.io/title: Cloudflare Certificate Standards
    policies.kyverno.io/category: Security
    policies.kyverno.io/severity: high
    policies.kyverno.io/subject: Secret
    policies.kyverno.io/description: >-
      Validates TLS secrets used with Cloudflare Origin Certificates
      follow proper naming and structure conventions.
spec:
  validationFailureAction: enforce
  background: true
  rules:
  - name: validate-cloudflare-origin-cert
    match:
      any:
      - resources:
          kinds:
          - Secret
          names:
          - "*gateway*cert*"
    validate:
      message: "Cloudflare Origin Certificate secrets must be properly formatted"
      pattern:
        type: "kubernetes.io/tls"
        data:
          tls.crt: "?*"
          tls.key: "?*"
YAML

  depends_on = [
    null_resource.verify_kyverno_webhooks,  # Wait for webhooks to be ready
    kubernetes_secret.cloudflare_origin_cert  # Certificate must exist for validation
  ]
}

# Resource Requirements Policy - Relaxed for operational flexibility
resource "kubectl_manifest" "kyverno_resource_requirements" {
  count = var.enable_kyverno ? 1 : 0
  yaml_body = <<-YAML
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: require-resource-requests
  annotations:
    policies.kyverno.io/title: Require Resource Requests
    policies.kyverno.io/category: Best Practices
    policies.kyverno.io/severity: medium
    policies.kyverno.io/subject: Pod
    policies.kyverno.io/description: >-
      Ensures production containers specify resource requests for CPU and memory.
      Allows exemptions for debug, testing, and temporary workloads.
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
      # Exclude system namespaces
      - resources:
          namespaces: 
          - kube-system
          - kyverno
          - kgateway-system
          - local-path-storage
          - istio-system
      # Exclude debug and temporary workloads
      - resources:
          selector:
            matchLabels:
              workload-type: debug
      - resources:
          selector:
            matchLabels:
              workload-type: temporary
      # Exclude jobs and cronjobs (often one-time tasks)
      - resources:
          selector:
            matchLabels:
              app.kubernetes.io/component: job
    validate:
      message: "Production containers should specify CPU and memory requests. Add label 'workload-type: debug' or 'workload-type: temporary' to exempt non-production workloads."
      anyPattern:
      # Allow pods with resource requests
      - spec:
          containers:
          - resources:
              requests:
                cpu: "?*"
                memory: "?*"
      # Allow pods with debug/temporary annotation (backup exemption)
      - metadata:
          annotations:
            policy.kyverno.io/exempt-resource-requests: "true"
YAML

  depends_on = [
    null_resource.verify_kyverno_webhooks  # Wait for webhooks to be ready
  ]
}