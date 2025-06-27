# Cilium CNI with Terraform

This document explains the Cilium CNI configuration used in this project and how it integrates with Terraform.

## Overview

[Cilium](https://cilium.io/) is a powerful CNI (Container Network Interface) that provides networking, security, and observability for Kubernetes clusters. In our infrastructure, we use Cilium v1.17.5 with Hubble enabled for enhanced observability.

## Deployment Architecture

Our Cilium deployment follows this architecture:

1. **Base Cluster**: Civo Kubernetes cluster with built-in Cilium (initially v1.11.6)
2. **Terraform Management**: We use Terraform to upgrade and manage Cilium via Helm
3. **Observability**: Hubble components (UI, Relay) are enabled for network flow visibility

## Terraform Implementation

We use a `null_resource` with a `local-exec` provisioner to manage Cilium, rather than the standard `helm_release` resource. This approach was chosen because:

1. The Civo cluster comes with Cilium pre-installed (via `cni = "cilium"` in the cluster configuration)
2. We need to upgrade the existing installation rather than create a new one
3. Direct Helm commands provide more flexibility for complex upgrade scenarios

```hcl
resource "null_resource" "cilium_upgrade" {
  triggers = {
    cilium_version = "1.17.5"
  }

  # ... provisioner details ...
}
```

The `triggers` block ensures that the resource is recreated when the Cilium version changes, allowing for future upgrades.

## Configuration Options

Our Cilium configuration includes:

| Option | Value | Purpose |
|--------|-------|---------|
| `image.repository` | `quay.io/cilium/cilium` | Official Cilium image repository |
| `image.tag` | `v1.17.5` | Specific version for consistency and stability |
| `installCRDs` | `true` | Automatically install/update Custom Resource Definitions |
| `kubeProxyReplacement` | `true` | Replace kube-proxy functionality with Cilium |
| `hubble.enabled` | `true` | Enable Hubble for network flow visibility |
| `hubble.relay.enabled` | `true` | Enable Hubble Relay for collecting flow data |
| `hubble.ui.enabled` | `true` | Enable Hubble UI for visualization |
| `metrics.enabled` | `true` | Enable Prometheus metrics |

### Key Components

1. **Cilium Agent**: The core CNI component that runs on each node
2. **Hubble**: Observability platform for Cilium
3. **Hubble Relay**: Aggregates flows from multiple nodes
4. **Hubble UI**: Web interface for visualizing network flows

## Upgrade Process

The upgrade process follows these steps:

1. Add the Cilium Helm repository
2. Create a values file with our desired configuration
3. Use `helm upgrade` to update the existing Cilium installation
4. The upgrade preserves existing settings while applying our new configuration

```bash
helm upgrade cilium cilium/cilium \
  --version 1.17.5 \
  --namespace kube-system \
  --reset-values \
  --reuse-values \
  --values cilium_values.yaml
```

## Accessing Hubble UI

Once deployed, you can access the Hubble UI by port-forwarding:

```bash
kubectl port-forward -n kube-system svc/hubble-ui 12000:80
```

Then navigate to http://localhost:12000 in your browser.

## Troubleshooting

### Common Issues

1. **Version Conflicts**: When upgrading across major versions, check the [Cilium upgrade guide](https://docs.cilium.io/en/stable/operations/upgrade/) for any breaking changes
2. **Helm Repository Missing**: Ensure the Cilium Helm repository is added with `helm repo add cilium https://helm.cilium.io`
3. **Deprecated Options**: Some options like `containerRuntime.integration` were deprecated in v1.14 and removed in v1.16

### Verification

Verify your Cilium installation with:

```bash
kubectl get pods -n kube-system -l k8s-app=cilium
cilium status --wait
```

## Benefits of This Approach

1. **Declarative Configuration**: Infrastructure as Code principles are maintained
2. **Version Control**: Cilium version and configuration are tracked in Git
3. **Automation**: Upgrades can be part of your CI/CD pipeline
4. **Flexibility**: Direct Helm commands allow for complex upgrade scenarios

## Future Considerations

1. **Cilium Network Policies**: Consider implementing network policies for enhanced security
2. **Cilium Service Mesh**: Evaluate Cilium's service mesh capabilities as an alternative to Istio/Linkerd
3. **eBPF Maps**: Monitor eBPF map usage for performance optimization
4. **Hubble Metrics**: Set up Grafana dashboards for Hubble metrics

## References

- [Cilium Documentation](https://docs.cilium.io/)
- [Hubble Documentation](https://docs.cilium.io/en/stable/gettingstarted/hubble/)
- [Cilium Helm Chart Values](https://github.com/cilium/cilium/tree/master/install/kubernetes/cilium)
