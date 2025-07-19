# Kyverno Integration Implementation Plan

This document provides a comprehensive plan for integrating Kyverno, a policy engine for Kubernetes, into the existing Terraform-based infrastructure. Kyverno will provide governance, security, and compliance capabilities across the cluster's workloads and infrastructure components.

## Overview

### What is Kyverno?

Kyverno is a Kubernetes-native policy engine that enables policy-as-code through Custom Resource Definitions (CRDs). It provides:

- **Validation**: Enforce rules on Kubernetes resources
- **Mutation**: Automatically modify resources to comply with standards
- **Generation**: Create supporting resources automatically
- **Verification**: Ensure workloads meet security requirements

### Integration Goals

1. **Governance**: Ensure cluster resources follow organizational standards
2. **Security**: Implement Pod Security Standards and network policy governance
3. **Compliance**: Automate compliance with security frameworks
4. **Gateway API Control**: Validate and enforce Gateway API resource configurations
5. **Cilium Integration**: Govern Cilium Network Policy creation and management
6. **Ambient Mesh Readiness**: Prepare policies for future Istio Ambient Mesh integration

## Architecture Integration

### Current Stack Compatibility

Kyverno integrates seamlessly with the existing infrastructure:

- **Civo Kubernetes (v1.30.5-k3s1)**: Full compatibility with modern Kubernetes features
- **Cilium CNI (v1.17.5)**: Policy governance for Cilium Network Policies
- **Gateway API (v1.2.1) + Kgateway (v2.0.3)**: HTTPRoute and Gateway resource validation
- **Cloudflare Integration**: DNS and certificate policy enforcement
- **Future Istio Ambient Mesh**: Pre-configured policies for ambient mode

### Deployment Strategy

Following the established Terraform patterns:
- **Conditional Deployment**: Enabled/disabled via Terraform variables
- **Helm-based Installation**: Using official Kyverno Helm charts
- **High Availability**: Production-ready configuration with multiple replicas
- **Namespace Isolation**: Dedicated `kyverno` namespace following cluster patterns

## Implementation Components

### 1. Core Terraform Files

#### `io.tf` Variable Additions

```hcl
# Kyverno Configuration
variable "enable_kyverno" {
  description = "Whether to deploy Kyverno policy engine"
  type        = bool
  default     = true
}

variable "kyverno_chart_version" {
  description = "Version of the Kyverno Helm chart"
  type        = string
  default     = "3.4.4"  # Latest stable version as of 2024
}

variable "kyverno_policies_chart_version" {
  description = "Version of the Kyverno Policies Helm chart"
  type        = string
  default     = "3.4.4"  # Latest stable version as of 2024
}

variable "enable_kyverno_policies" {
  description = "Whether to deploy pre-built Kyverno policies"
  type        = bool
  default     = true
}

variable "kyverno_policy_exclusions" {
  description = "Namespaces to exclude from Kyverno policies"
  type        = list(string)
  default     = ["kube-system", "kyverno", "kgateway-system", "local-path-storage"]
}
```

#### `helm_kyverno.tf` - Main Kyverno Engine

```hcl
# Kyverno Policy Engine - Kubernetes-native policy management
# https://kyverno.io/docs/installation/

resource "helm_release" "kyverno" {
  count      = var.enable_kyverno ? 1 : 0
  name       = "kyverno"
  repository = "https://kyverno.github.io/kyverno/"
  chart      = "kyverno"
  version    = var.kyverno_chart_version
  namespace  = "kyverno"
  create_namespace = true

  # High availability configuration for production
  values = [
    yamlencode({
      # Admission Controller Configuration
      admissionController = {
        replicas = 3
        resources = {
          limits = {
            cpu    = "1000m"
            memory = "512Mi"
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
        affinity = {
          podAntiAffinity = {
            preferredDuringSchedulingIgnoredDuringExecution = [
              {
                weight = 100
                podAffinityTerm = {
                  labelSelector = {
                    matchLabels = {
                      "app.kubernetes.io/name" = "kyverno"
                      "app.kubernetes.io/component" = "admission-controller"
                    }
                  }
                  topologyKey = "kubernetes.io/hostname"
                }
              }
            ]
          }
        }
      }

      # Background Controller Configuration
      backgroundController = {
        replicas = 2
        resources = {
          limits = {
            cpu    = "1000m"
            memory = "512Mi"
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
      }

      # Cleanup Controller Configuration
      cleanupController = {
        replicas = 2
        resources = {
          limits = {
            cpu    = "200m"
            memory = "256Mi"
          }
          requests = {
            cpu    = "50m"
            memory = "128Mi"
          }
        }
        securityContext = {
          runAsNonRoot = true
          runAsUser    = 1000
          fsGroup      = 1000
        }
      }

      # Reports Controller Configuration
      reportsController = {
        replicas = 2
        resources = {
          limits = {
            cpu    = "200m"
            memory = "256Mi"
          }
          requests = {
            cpu    = "50m"
            memory = "128Mi"
          }
        }
        securityContext = {
          runAsNonRoot = true
          runAsUser    = 1000
          fsGroup      = 1000
        }
      }

      # Configuration
      config = {
        # Exclude system namespaces for operational safety
        webhooks = [
          {
            namespaceSelector = {
              matchExpressions = [
                {
                  key      = "kubernetes.io/metadata.name"
                  operator = "NotIn"
                  values   = var.kyverno_policy_exclusions
                }
              ]
            }
          }
        ]
      }

      # Features Configuration
      features = {
        # Enable policy exceptions for flexibility
        policyExceptions = {
          enabled = true
        }
        # Enable admission reports for observability
        admissionReports = {
          enabled = true
        }
        # Enable background scanning
        backgroundScan = {
          enabled = true
        }
      }
    })
  ]

  depends_on = [
    time_sleep.wait_for_cluster,
    null_resource.cilium_upgrade  # Ensure Cilium is ready before policies
  ]
}
```

#### `helm_kyverno_policies.tf` - Pre-built Policy Sets

```hcl
# Kyverno Pre-built Policies - Common security and best practice policies
# https://kyverno.io/policies/

resource "helm_release" "kyverno_policies" {
  count      = var.enable_kyverno && var.enable_kyverno_policies ? 1 : 0
  name       = "kyverno-policies"
  repository = "https://kyverno.github.io/kyverno/"
  chart      = "kyverno-policies"
  version    = var.kyverno_policies_chart_version
  namespace  = "kyverno"
  create_namespace = false

  values = [
    yamlencode({
      # Pod Security Standards - Baseline profile
      podSecurityStandard = "baseline"
      
      # Include specific policy categories
      include = [
        "pod-security-standard-baseline",
        "best-practices",
        "security"
      ]

      # Exclude policies that might conflict with service mesh requirements
      exclude = [
        "restrict-seccomp-strict",  # May conflict with Istio sidecars
        "require-run-as-non-root-user"  # May conflict with init containers
      ]

      # Policy enforcement mode
      policyViolationAction = "enforce"

      # Namespace exclusions (same as main Kyverno config)
      namespaceSelector = {
        matchExpressions = [
          {
            key      = "kubernetes.io/metadata.name"
            operator = "NotIn"
            values   = var.kyverno_policy_exclusions
          }
        ]
      }

      # Background scanning configuration
      background = true
    })
  ]

  depends_on = [
    helm_release.kyverno
  ]
}
```

### 2. Custom Policy Configurations

#### `kyverno_custom_policies.tf` - Cluster-Specific Policies

```hcl
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
    helm_release.kyverno
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
  - name: deny-default-allow-all
    match:
      any:
      - resources:
          kinds:
          - CiliumNetworkPolicy
    validate:
      message: "CiliumNetworkPolicy cannot allow all traffic by default"
      deny:
        conditions:
        - key: "{{ request.object.spec.ingress || `[]` | length(@) }}"
          operator: Equals
          value: 0
        - key: "{{ request.object.spec.egress || `[]` | length(@) }}"
          operator: Equals
          value: 0
YAML

  depends_on = [
    helm_release.kyverno
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
    helm_release.kyverno
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
    helm_release.kyverno
  ]
}
```

### 3. HTTPRoute Integration for Kyverno UI

#### `httproute_kyverno.tf` - Web UI Access

```hcl
# Kyverno UI HTTPRoute for web-based policy management

resource "kubectl_manifest" "httproute_kyverno" {
  count = var.enable_kyverno ? 1 : 0
  yaml_body = <<-YAML
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: kyverno-ui
  namespace: kyverno
spec:
  parentRefs:
  - name: default-gateway
    namespace: default
    kind: Gateway
  hostnames:
  - "kyverno.${var.domain_name}"
  rules:
  - matches:
    - path:
        type: PathPrefix
        value: /
    backendRefs:
    - name: kyverno-ui
      port: 8080
      kind: Service
YAML

  depends_on = [
    helm_release.kyverno,
    kubectl_manifest.default_gateway
  ]
}

# ReferenceGrant for cross-namespace Gateway access
resource "kubectl_manifest" "reference_grant_kyverno" {
  count = var.enable_kyverno ? 1 : 0
  yaml_body = <<-YAML
apiVersion: gateway.networking.k8s.io/v1beta1
kind: ReferenceGrant
metadata:
  name: allow-kyverno-to-default-gateway
  namespace: default
spec:
  from:
  - group: gateway.networking.k8s.io
    kind: HTTPRoute
    namespace: kyverno
  to:
  - group: gateway.networking.k8s.io
    kind: Gateway
    name: default-gateway
YAML

  depends_on = [
    helm_release.kyverno,
    kubectl_manifest.default_gateway
  ]
}
```

## Execution Order and Dependencies

### 1. Prerequisites

Before Kyverno deployment:
- Cluster creation and readiness (`time_sleep.wait_for_cluster`)
- Cilium CNI upgrade completion (`null_resource.cilium_upgrade`)
- Gateway API CRDs installation (for Gateway API policies)

### 2. Kyverno Deployment Sequence

1. **Kyverno Engine** (`helm_release.kyverno`)
   - Admission controllers with HA configuration
   - Background and cleanup controllers
   - Reports controller for observability

2. **Pre-built Policies** (`helm_release.kyverno_policies`)
   - Pod Security Standards baseline
   - Best practices and security policies
   - Depends on Kyverno engine

3. **Custom Policies** (`kubectl_manifest.kyverno_*_policy`)
   - Gateway API governance
   - Cilium Network Policy governance
   - Ambient Mesh preparation
   - Certificate standards

4. **UI Access** (`httproute_kyverno`)
   - Web interface for policy management
   - Exposed through default Gateway

### 3. Integration Timeline

- **Immediate**: Basic policy enforcement and validation
- **Short-term**: Custom governance policies for Gateway API and Cilium
- **Medium-term**: Enhanced policies for application security
- **Long-term**: Istio Ambient Mesh policy integration

## Policy Categories and Examples

### 1. Security Policies

**Pod Security Standards**: Enforce baseline security requirements for all pods
**Network Security**: Govern Cilium Network Policy creation and configuration
**Certificate Management**: Validate TLS certificate usage and formats

### 2. Governance Policies

**Resource Standards**: Enforce naming conventions and required annotations
**Gateway API Control**: Validate HTTPRoute and Gateway configurations
**Namespace Management**: Automatic labeling and configuration

### 3. Compliance Policies

**Audit Requirements**: Ensure resources include required metadata
**Access Control**: Validate RBAC configurations
**Data Protection**: Enforce encryption and security contexts

### 4. Operational Policies

**Resource Limits**: Enforce CPU and memory limits
**Health Checks**: Require readiness and liveness probes
**Monitoring**: Ensure observability configurations

## Integration-Specific Configurations

### Cilium CNI Integration

- **Network Policy Governance**: Validate Cilium Network Policy configurations
- **Annotation Requirements**: Enforce metadata for policy tracking
- **Security Baselines**: Prevent overly permissive network policies

### Gateway API Integration

- **HTTPRoute Validation**: Ensure proper Gateway references
- **Hostname Standards**: Enforce domain naming conventions
- **TLS Requirements**: Validate certificate configurations

### Ambient Mesh Preparation

- **Namespace Labeling**: Automatic ambient mode label application
- **Authorization Policies**: Require AuthorizationPolicy resources
- **Service Mesh Compatibility**: Ensure workload compatibility

### Cloudflare Integration

- **Certificate Validation**: Ensure proper Origin Certificate usage
- **DNS Policy**: Validate DNS record configurations
- **Security Headers**: Enforce security best practices

## Monitoring and Observability

### 1. Policy Reports

Kyverno generates comprehensive reports on policy compliance:
- **Admission Reports**: Real-time policy evaluation results
- **Background Reports**: Cluster-wide compliance scanning
- **Policy Exceptions**: Tracked deviations with justifications

### 2. Metrics and Alerting

Integration with cluster monitoring:
- **Policy Violations**: Track enforcement actions
- **Resource Changes**: Monitor policy-driven mutations
- **Performance Metrics**: Admission controller latency

### 3. Audit Trail

Complete policy enforcement audit:
- **Policy Changes**: Track policy updates and versions
- **Enforcement Actions**: Log all policy decisions
- **Exception Handling**: Monitor policy exception usage

## Troubleshooting Guide

### Common Issues

**1. Policy Conflicts**
- *Symptom*: Resources failing admission
- *Solution*: Review policy exclusions and namespace selectors
- *Prevention*: Use policy validation in test environments

**2. Performance Impact**
- *Symptom*: Slow resource creation
- *Solution*: Tune admission controller resources and replicas
- *Prevention*: Monitor policy complexity and scope

**3. Service Mesh Compatibility**
- *Symptom*: Init container failures
- *Solution*: Update Pod Security policies for service mesh
- *Prevention*: Use service mesh-aware policy configurations

### Validation Commands

```bash
# Check Kyverno installation
kubectl get pods -n kyverno

# Verify policy status
kubectl get clusterpolicies

# Review policy reports
kubectl get clusterpolicyreports

# Test policy against resource
kyverno apply policy.yaml --resource resource.yaml
```

## Future Roadmap

### Phase 1: Foundation (Immediate)
- [x] Core Kyverno engine deployment
- [x] Basic security policies
- [x] Gateway API governance

### Phase 2: Integration (1-2 months)
- [ ] Cilium Network Policy governance
- [ ] Enhanced security policies
- [ ] Compliance reporting

### Phase 3: Advanced Features (3-6 months)
- [ ] Istio Ambient Mesh policies
- [ ] Custom policy development
- [ ] Advanced automation

### Phase 4: Optimization (6-12 months)
- [ ] Performance tuning
- [ ] Policy optimization
- [ ] Enterprise features

## Maintenance and Updates

### Regular Tasks

**Weekly**:
- Review policy reports and violations
- Monitor admission controller performance

**Monthly**:
- Update Kyverno charts to latest versions
- Review and tune policy configurations
- Assess new policy requirements

**Quarterly**:
- Comprehensive policy audit
- Performance optimization review
- Security policy updates

### Update Procedures

**Kyverno Engine Updates**:
1. Test in non-production environment
2. Review breaking changes and deprecations
3. Update Terraform variables
4. Apply with Terraform

**Policy Updates**:
1. Validate policies in test environment
2. Review impact on existing workloads
3. Implement with gradual rollout
4. Monitor compliance reports

This implementation plan provides a comprehensive, production-ready integration of Kyverno into the existing Terraform infrastructure, following established patterns while providing robust policy governance capabilities.