# Component Versions

This document provides a comprehensive list of all components and their versions deployed in the Kubernetes cluster.

## Core Infrastructure

| Component | Version | Description |
|-----------|---------|-------------|
| Kubernetes | 1.30.5-k3s1 | Base Kubernetes cluster running on Civo Cloud |
| Terraform | N/A | Infrastructure as Code tool used to manage all resources |
| CSI Snapshot Controller | latest | Volume snapshot functionality for persistent storage |
| Civo Volume Snapshot Class | N/A | Storage class for volume snapshots on Civo Cloud |

## Networking Stack

| Component | Version | Description |
|-----------|---------|-------------|
| Cilium CNI | v1.17.5 | Container Network Interface providing networking and network policy |
| Hubble | v1.17.5 | Observability layer for Cilium providing network flow visibility |
| Gateway API | v1.2.1 | Kubernetes Gateway API CRDs for modern ingress management |
| Kgateway | v2.0.3 | Gateway API implementation for ingress traffic |

## Security & Certificate Management

| Component | Version | Description |
|-----------|---------|-------------|
| Cloudflare Origin Certificates | N/A | TLS certificates provided by Cloudflare for secure connections |
| Cloudflare DNS | N/A | DNS provider with proxying enabled for additional security |
| Cloudflare SSL/TLS | Full | Encryption mode used between Cloudflare and origin server |

## Policy Engine & Governance

| Component | Version | Description |
|-----------|---------|-------------|
| Kyverno | v1.14.4 (Chart: v3.4.4) | Cloud-native policy engine for Kubernetes security and governance |
| Kyverno Policies | v3.4.4 | Pre-built security policies (Pod Security Standards baseline) |
| Policy Reporter | v2.22.0 | Web-based UI for Kyverno policy management and compliance reporting |

## Continuous Integration & Workflows

| Component | Version | Description |
|-----------|---------|-------------|
| Argo Workflows | v3.6.10 (Chart: v0.45.19) | Container-native workflow engine for CI/CD |
| Argo Events | v1.9.6 (Chart: v2.4.15) | Event-driven workflow automation |
| EventBus (JetStream) | v2.10.10 | Event streaming for Argo Events communication |
| Metrics Server | v3.12.1 | Kubernetes resource metrics collection |

## Service Mesh

| Component | Version | Description |
|-----------|---------|-------------|
| Gloo Operator | Latest | Operator for managing Istio lifecycle |
| Istio | v1.26.2 | Service mesh platform with Ambient Mesh mode |
| Istio CNI | v1.26.2 | CNI plugin for traffic interception (chained with Cilium) |
| Ztunnel | v1.26.2 | Ambient data plane proxy for east-west traffic |

## Observability Stack

| Component | Version | Description |
|-----------|---------|-------------|
| Prometheus Operator | v61.9.0 | Cloud-native monitoring stack with kube-prometheus-stack |
| Prometheus Server | Included | Metrics collection and monitoring (via Prometheus Operator) |
| Alertmanager | Included | Alert routing and management (via Prometheus Operator) |
| Node Exporter | Included | System-level metrics collection (via Prometheus Operator) |
| kube-state-metrics | Included | Kubernetes resource metrics (via Prometheus Operator) |
| Grafana | latest | Metrics visualization with 10 pre-configured dashboards |
| Kiali | latest | Service mesh observability and management |

### Grafana Dashboards (Pre-configured)

| Dashboard | Grafana ID | Description |
|-----------|------------|-------------|
| Kubernetes Cluster Monitoring | 7249 | Overall cluster resource monitoring |
| Node Exporter Full | 1860 | Detailed node-level system metrics |
| Kubernetes Pods | 6417 | Pod-level resource utilization |
| Istio Control Plane | 7645 | Istio control plane component monitoring |
| Istio Mesh | 7639 | Service mesh traffic and performance |
| Cilium Metrics | 16611 | CNI and network policy monitoring |
| Prometheus Stats | 2 | Prometheus server performance metrics |
| Kubernetes API Server | 12006 | API server performance and health |
| Kube State Metrics | 13332 | Kubernetes object state monitoring |
| Alertmanager | 9578 | Alert management and routing status |

## Database Platform

| Component | Version | Description |
|-----------|---------|-------------|
| KubeBlocks | v1.0.0 | Cloud-native database management platform |
| PostgreSQL Addon | Latest | PostgreSQL database engine support |
| Redis Addon | Latest | Redis in-memory database support |
| MongoDB Addon | Latest | MongoDB document database support |

## Provider Versions (Terraform)

| Provider | Version | Description |
|----------|---------|-------------|
| Civo | 1.0.35 | Civo Cloud infrastructure provider |
| Kubernetes | 2.31.0 | Kubernetes resource management |
| Helm | 2.13.1 | Helm chart deployment |
| Kubectl | 2.5.1 | Direct kubectl manifest application |
| Cloudflare | 5.5.0 | DNS and certificate management |
| Local | ~> 2.0 | Local file operations |
| Time | ~> 0.10.0 | Time-based dependencies |
| Null | ~> 3.0 | Null resource operations |

## Custom Policy Framework

The cluster implements a comprehensive custom policy framework through Kyverno:

### Built-in Policies
- **Pod Security Standards**: Baseline security policies for pod hardening
- **Resource Requirements**: CPU and memory request enforcement
- **Network Policies**: Validation for proper network segmentation

### Custom Cluster Policies
- **Gateway API HTTPRoute Standards**: Ensures proper Gateway references and domain conventions
- **Cilium Network Policy Governance**: Validates network policy annotations and rules
- **Istio Ambient Mesh Preparation**: Automatic namespace labeling for mesh inclusion
- **Cloudflare Certificate Standards**: TLS secret validation and formatting
- **Resource Requirements**: Production workload resource enforcement with debug exemptions

### Policy Exclusions
The following namespaces are excluded from policy enforcement:
- `kube-system`, `kyverno`, `kgateway-system`, `local-path-storage`, `istio-system`, `monitoring`, `policy-reporter`


## Notes

### Infrastructure Management
- All components are deployed and managed via Terraform
- Infrastructure follows GitOps principles with declarative configuration
- Version pinning is configurable via Terraform variables for all components
- Resource requests and limits are enforced through Kyverno policies

### Networking Architecture
- Cilium CNI configured with Hubble for observability and `cni.exclusive: false` for Ambient Mesh compatibility
- Kgateway configured with wildcard TLS certificate for all subdomains via Cloudflare Origin Certificates
- Gateway API v1.2 provides modern, extensible ingress with HTTPRoute resources
- All external services accessible via HTTPRoutes through the default Gateway

### Service Mesh Configuration
- Ambient Mesh installed via Gloo Operator with specific configuration for Cilium compatibility:
  - Istio CNI configured as a chained plugin alongside Cilium
  - eBPF used for traffic redirection in ztunnel
  - `PILOT_ENABLE_AMBIENT` environment variable set for istiod
  - Installation order: istio-base → istio-cni → istiod → ztunnel
- k3s platform-specific optimizations applied

### Monitoring Architecture
- **Prometheus Operator Stack**: Comprehensive monitoring with kube-prometheus-stack deployment
- **Conditional Deployment**: Supports both basic Prometheus and Prometheus Operator based on `enable_prometheus_operator` variable
- **ServiceMonitor Integration**: Automatic service discovery for Policy Reporter and other components when Prometheus Operator is enabled
- **Cross-namespace Monitoring**: Prometheus Operator deployed in dedicated `monitoring` namespace with cluster-wide scraping

### Policy Governance
- **Comprehensive Policy Framework**: 11 pre-built + 5 custom policies covering security, networking, and resource management
- **Real-time Enforcement**: New resources validated at creation time with background scanning for existing resources
- **Web-based Management**: Policy Reporter UI provides centralized policy compliance dashboards
- **Flexible Exemptions**: Namespace and label-based exemptions for system components and development workloads

### Database Management
- **KubeBlocks Operator**: Unified database management platform for PostgreSQL, Redis, and MongoDB
- **Cloud-native Storage**: Persistent volumes with snapshot capabilities via Civo Cloud CSI
- **High Availability**: Built-in clustering and backup capabilities for production databases

### Workflow Automation (Optional)
- Argo Workflows provides in-cluster CI/CD with event-driven automation via Argo Events
- JetStream EventBus enables reliable event streaming between workflow components
- Kaniko integration available for secure container builds without Docker daemon
