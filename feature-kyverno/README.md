# Kyverno Policy Engine Feature Module

This module deploys and configures Kyverno Policy Engine for Kubernetes policy-as-code governance.

## Components Deployed

### Core Kyverno Engine
- **Kyverno Admission Controller**: Validates and mutates resources in real-time (3 replicas for HA)
- **Kyverno Background Controller**: Handles background scanning and policy evaluation (2 replicas)
- **Kyverno Cleanup Controller**: Manages TTL and cleanup operations (2 replicas)
- **Kyverno Reports Controller**: Generates policy compliance reports (2 replicas)

### Policy Collections
- **Pre-built Security Policies**: Industry-standard baseline security policies (optional)
- **Custom Cluster Policies**: Organization-specific governance rules including:
  - Gateway API HTTPRoute validation
  - Cilium NetworkPolicy governance
  - Istio Ambient Mesh preparation
  - Cloudflare certificate validation
  - Resource requirements enforcement (audit mode)

### Policy Management UI
- **Policy Reporter**: Web-based dashboard for policy violation tracking and compliance reporting
- **Prometheus Integration**: Metrics and monitoring when Prometheus Operator is enabled
- **Gateway API Integration**: Accessible via HTTPS through the default Gateway

## Configuration

### Key Features
- **Audit Mode**: All policies run in audit mode by default (non-blocking)
- **Webhook Failure Policy**: Set to "Ignore" to prevent cluster disruption
- **Namespace Exclusions**: System namespaces are automatically excluded
- **High Availability**: Multiple replicas with pod anti-affinity rules

### Resource Requirements
- Admission Controllers: 100m CPU / 256Mi memory (request), 1000m CPU / 512Mi memory (limit)
- Background Controllers: 100m CPU / 256Mi memory (request), 1000m CPU / 512Mi memory (limit)
- Other Controllers: 50m CPU / 128Mi memory (request), 200m CPU / 256Mi memory (limit)

## Usage

### Enable Kyverno
```hcl
enable_kyverno = true
enable_kyverno_policies = true
enable_policy_reporter_ui = true
```

### Access Policy Reporter UI
When enabled, Policy Reporter is accessible at:
```
https://policy-reporter.${var.domain_name}
```

### Monitor Policy Status
```bash
# Check Kyverno deployment
kubectl get pods -n kyverno

# View active policies
kubectl get clusterpolicies

# Check policy violations
kubectl get policyreports -A
kubectl get clusterpolicyreports
```

## Custom Policies

This module includes several custom policies tailored for the cluster architecture:

### Gateway API HTTPRoute Standards
- Ensures HTTPRoutes reference the default-gateway
- Validates hostname patterns match the configured domain

### Cilium Network Policy Governance
- Requires owner and purpose annotations
- Validates explicit ingress/egress rules (prevents accidental allow-all policies)

### Istio Ambient Mesh Preparation
- Automatically adds ambient mesh labels when namespaces are annotated
- Simplifies service mesh onboarding

### Resource Requirements Policy
- Encourages resource requests for production workloads
- Provides exemptions for debug/temporary workloads
- Runs in audit mode for operational flexibility

## Security Considerations

- All policies run in **audit mode** to prevent cluster disruption
- Webhook failure policy set to "Ignore" for operational safety
- System namespaces automatically excluded from policy enforcement
- Policy exceptions restricted to the kyverno namespace only
- Resource requirements policy includes multiple exemption mechanisms

## Troubleshooting

### Verify Kyverno Installation
```bash
# Check admission controllers are ready
kubectl get pods -n kyverno -l app.kubernetes.io/component=admission-controller

# Verify webhooks are registered
kubectl get validatingwebhookconfigurations | grep kyverno
kubectl get mutatingwebhookconfigurations | grep kyverno
```

### Policy Debugging
```bash
# View policy violations
kubectl describe policyreport -n <namespace>

# Check specific policy details
kubectl describe clusterpolicy <policy-name>

# View Kyverno logs
kubectl logs -n kyverno -l app.kubernetes.io/component=admission-controller
```

## Integration Notes

This module is designed to work seamlessly with:
- **Gateway API**: Custom HTTPRoute validation policies
- **Cilium CNI**: Network policy governance rules
- **Istio Ambient Mesh**: Automatic namespace preparation
- **Prometheus Operator**: Policy metrics and monitoring
- **Cloudflare Certificates**: TLS secret validation

The module maintains operational safety through audit-only enforcement while providing comprehensive policy governance for the cluster.