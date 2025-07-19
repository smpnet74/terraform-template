# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

This is a Terraform-based infrastructure template for deploying a clean, production-ready Kubernetes cluster on Civo Cloud. It provides a foundational stack with Cilium CNI, Gateway API with Kgateway, automated TLS certificate management, and is optimized for external GitOps solutions like GitHub Actions CI/CD.

## Key Commands

### Infrastructure Deployment

```bash
# Initialize Terraform
terraform init

# Plan deployment (review changes before applying)
terraform plan

# Deploy infrastructure
terraform apply

# Destroy infrastructure (note: may need to run twice due to firewall timeout)
terraform destroy
```

### Configuration Setup

```bash
# Copy and customize variables file
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your specific values
```

### Cluster Access

```bash
# Use generated kubeconfig for cluster access
export KUBECONFIG=./kubeconfig
kubectl get nodes

# Verify cluster components
kubectl get pods -A
```

## Architecture Overview

### Core Infrastructure Stack
- **Civo Kubernetes Cluster**: Managed cluster (v1.30.5-k3s1) with Cilium CNI
- **Cilium CNI**: Network plugin (v1.17.5) with Hubble observability, configured for Ambient Mesh compatibility (`cni.exclusive: false`)
- **Gateway API + Kgateway**: Modern ingress using Gateway API v1.2.1 with Kgateway v2.0.3 for advanced routing
- **Cloudflare Integration**: DNS management and Origin Certificates for TLS termination
- **Metrics Server**: Kubernetes resource utilization metrics for monitoring and autoscaling
- **Istio Ambient Mesh**: Service mesh prepared for implementation

### Optional Components
- **Argo Workflows + Events**: Event-driven workflow automation platform (controlled by `enable_argo_workflows`)
- **Istio Ambient Mesh**: Service mesh prepared for future implementation

### Execution Dependencies

The Terraform configuration follows a strict execution order:
1. Cluster + Firewall creation → Cilium upgrade → TLS certificates
2. Gateway API CRDs → Kgateway CRDs → Kgateway deployment → Default Gateway
3. DNS configuration → Optional workflow deployments

## File Organization

### Core Infrastructure Files
- `provider.tf`: All Terraform providers (Civo, Kubernetes, Helm, Cloudflare, kubectl, time)
- `io.tf`: Input/output variable definitions
- `cluster.tf`: Civo cluster creation and kubeconfig generation
- `cluster_ready_delay.tf`: Ensures cluster API server readiness
- `helm_metrics_server.tf`: Kubernetes resource utilization metrics collection

### Networking & Security
- `helm_cilium.tf`: Cilium CNI upgrade with Ambient Mesh compatibility
- `cilium_values.yaml`: Cilium configuration values
- `civo_firewall-*.tf`: Firewall rules for API server and ingress traffic
- `kgateway_api.tf`: Gateway API CRDs, Kgateway deployment, and default Gateway
- `kgateway_certificate.tf`: Cloudflare Origin Certificate for TLS

### DNS & Certificates
- `cloudflare_dns.tf`: DNS A records (root and wildcard) with Cloudflare proxying
- Gateway uses Cloudflare Origin Certificates stored in `/certs/` directory

### Optional Components
- `argo_workflows.tf`: Argo Workflows + Events setup with EventBus for event-driven automation

## Variable Configuration

Key variables to customize in `terraform.tfvars`:

```hcl
# Required: Cloud provider token
civo_token = "your-civo-api-token"

# Required: DNS and certificates
domain_name = "your-domain.com"
cloudflare_api_token = "your-cloudflare-api-token"
cloudflare_zone_id = "your-cloudflare-zone-id"
cloudflare_email = "your-cloudflare-email"

# Optional: Cluster configuration
cluster_node_size = "g4s.kube.small"
region = "NYC1"

# Optional: Argo Workflows configuration
enable_argo_workflows = true
argo_workflows_chart_version = "0.45.19"  # Argo Workflows 3.6.10
argo_events_chart_version = "2.4.15"      # Compatible with Argo Workflows 3.6.10
jetstream_version = "2.10.10"             # Uses config reloader 0.14.0 (stable version)
metrics_server_chart_version = "3.12.1"  # Latest stable version
```

## Security Considerations

- **TLS Certificates**: Uses Cloudflare Origin Certificates stored locally in `/certs/` (not committed to Git)
- **Secrets Management**: API tokens stored as Terraform variables, Kubernetes secrets created for cluster components
- **Network Policies**: Firewall rules restrict access to Kubernetes API (6443) and web services (80/443)
- **External GitOps**: Optimized for external CI/CD solutions like GitHub Actions

## Key Patterns

### Modular Component Design
- Optional components use conditional deployment (`count = var.enable_feature ? 1 : 0`)
- Clear separation between infrastructure and application concerns
- Reusable patterns for extending functionality

### Gateway API Architecture
- Standard Gateway API CRDs provide vendor-neutral compatibility
- Kgateway CRDs add vendor-specific advanced features
- HTTPRoute resources handle application routing with cross-namespace access via ReferenceGrants

## Common Development Workflows

### Infrastructure Changes
1. Modify Terraform files following existing patterns
2. Run `terraform plan` to review changes
3. Apply with `terraform apply`
4. Verify deployment with `kubectl`

### Application Deployment
This cluster is optimized for external GitOps solutions. Recommended approaches:

1. **GitHub Actions CI/CD**: Build images, push to registry, deploy via kubectl
2. **Manual kubectl deployment**: Direct application of Kubernetes manifests
3. **Helm deployments**: Using Helm charts for complex applications
4. **External ArgoCD**: Point external ArgoCD instance at this cluster

### Troubleshooting
- Check `/docs` directory for component-specific troubleshooting guides
- Use `kubectl` with generated kubeconfig for cluster debugging
- Monitor cluster components: `kubectl get pods -A`

## Direct Application Deployment Example

### CoAgents Travel App Deployment
Example of deploying applications directly to the cluster:

```bash
# Deploy travel app from external repository
kubectl apply -f /path/to/app/k8s/namespace.yaml

# Create application secrets
kubectl create secret generic app-secrets -n app-namespace \
  --from-literal=API_KEY="your-api-key" \
  --from-literal=OTHER_SECRET="your-secret"

# Create image pull secret (for private registries)
kubectl create secret docker-registry registry-secret -n app-namespace \
  --docker-server=ghcr.io \
  --docker-username=your-username \
  --docker-password="your-token"

# Deploy application manifests
kubectl apply -f /path/to/app/k8s/

# Create HTTPRoute for external access
kubectl apply -f /path/to/app/httproute.yaml
```

### Application Architecture Best Practices
- **Namespacing**: Use dedicated namespaces for applications
- **Service Discovery**: Use Kubernetes DNS for inter-service communication
- **TLS Termination**: Configure HTTPRoutes to use the default Gateway with Cloudflare certificates
- **Health Checks**: Implement readiness and liveness probes
- **Resource Limits**: Set appropriate resource requests and limits

## External GitOps Integration

This cluster is designed to work seamlessly with external GitOps solutions:

### GitHub Actions Example
```yaml
- name: Deploy to Kubernetes
  run: |
    echo "${{ secrets.KUBECONFIG }}" | base64 -d > kubeconfig
    export KUBECONFIG=kubeconfig
    kubectl apply -f k8s/
    kubectl rollout status deployment/app-name -n app-namespace
```

### External ArgoCD Integration
- Point ArgoCD at your application repositories
- Use the cluster's kubeconfig for ArgoCD cluster configuration
- Applications can use the default Gateway for external access

## Cluster Features

### Networking
- **Cilium CNI**: Advanced networking with eBPF
- **Gateway API**: Modern, extensible ingress
- **Cloudflare Integration**: Global CDN and DDoS protection
- **TLS Automation**: Automatic certificate management

### Observability
- **Hubble**: Network observability (when Cilium observability is enabled)
- **Gateway Metrics**: Built-in Kgateway metrics
- **Cluster Metrics**: Standard Kubernetes metrics

### Security
- **Network Policies**: Cilium-based microsegmentation
- **TLS Everywhere**: End-to-end encryption
- **RBAC**: Kubernetes role-based access control
- **Firewall Rules**: Civo Cloud firewall protection

## Current Cluster Status

This is a clean, production-ready Kubernetes cluster optimized for:
- **External GitOps workflows** (GitHub Actions, GitLab CI, etc.)
- **Manual application deployment** via kubectl
- **Helm-based deployments**
- **External ArgoCD or Flux integration**
- **Development and production workloads**

The cluster provides a solid foundation without opinionated application deployment patterns, allowing teams to choose their preferred GitOps or deployment methodology.

## Memories

- Learned how to memorize text in a markdown file