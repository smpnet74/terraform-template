# Terraform Files Documentation

This document provides a comprehensive overview of all Terraform files in this project and explains their purpose, dependencies, and role in the infrastructure deployment.

## Core Infrastructure

### `provider.tf`
Configures the Terraform providers used in the project, including:
- **Civo**: Kubernetes cluster management (v1.0.35)
- **Kubernetes**: Resource management within the cluster (v2.31.0)
- **Helm**: Chart deployments (v2.13.1)
- **kubectl**: Custom resource management (~v1.14)
- **Cloudflare**: DNS and certificate management (v5.5.0)
- **GitHub**: Repository management for GitOps (~v6.0)
- **time**: Deployment delays and timing (~v0.10.0)
- **local**: Local file management (v2.5.1)

### `cluster.tf`
Creates and configures the Civo Kubernetes cluster with:
- **Cluster Configuration**: Configurable node count and size (default: 3 nodes, g4s.kube.medium)
- **Kubernetes Version**: 1.30.5-k3s1
- **Cilium CNI**: Network layer with Ambient Mesh compatibility
- **Kubeconfig Generation**: Local cluster access configuration with 0600 permissions
- **Dependencies**: Core foundation for all other resources
- **Firewall Integration**: Uses civo_firewall.firewall.id for security

### `io.tf`
Defines all input variables for the Terraform project, including:
- **Infrastructure Variables**: Cluster size, region (default: FRA1), node configuration
- **Networking Variables**: Firewall rules, domain configuration (default: timbersedgearb.com)
- **Integration Variables**: Civo, GitHub, Cloudflare API tokens
- **Feature Toggles**: Enable/disable Argo Workflows (default: false), Kyverno (default: true), Prometheus Operator (default: true)
- **Policy Configuration**: Kyverno policy exclusions, Policy Reporter UI settings
- **Monitoring Variables**: Prometheus Operator version (v61.9.0), monitoring namespace
- **Version Control**: Pinned versions for Argo Workflows (v0.45.19), Argo Events (v2.4.15), JetStream (v2.10.10), Metrics Server (v3.12.1), Kyverno (v3.4.4), Policy Reporter (v2.22.0)

### `outputs.tf`
Defines output values displayed after deployment:
- **Access URLs**: Kiali, Grafana, Argo Workflows, Policy Reporter endpoints
- **Access Commands**: Hubble UI, Kiali port-forward, Civo kubeconfig commands
- **Platform Information**: KubeBlocks usage instructions and test scripts
- **Policy Information**: Kyverno status commands and policy framework details
- **Monitoring Stack**: Prometheus Operator components and port-forward commands
- **Credentials**: Default Grafana credentials (admin/admin)

### `cluster_ready_delay.tf`
Implements timing controls to ensure cluster readiness:
- **60-second delay** after cluster creation
- **Ensures API server stability** before deploying workloads
- **Critical for reliable deployments**

### `kubectl_dependencies.tf`
Configures the kubectl provider with proper dependencies:
- **Cluster Readiness**: Waits for cluster and delay completion
- **Kubeconfig Path**: Uses local kubeconfig file
- **Provider Configuration**: Ensures kubectl operations work reliably

## Networking and Security

### `civo_firewall-cluster.tf`
Configures Civo firewall rules for cluster API access:
- **Port 6443**: Kubernetes API server access
- **Configurable CIDR blocks**: Control API access from specific networks (default: 0.0.0.0/0)
- **Security**: Restricts cluster management access
- **Cleanup Delay**: 240s wait before firewall destruction

### `civo_firewall-ingress.tf`
Configures Civo firewall rules for ingress traffic:
- **Port 80**: HTTP web traffic access
- **Port 443**: HTTPS secure web traffic access
- **Configurable CIDR blocks**: Control web access from specific networks (default: 0.0.0.0/0)
- **Load Balancer Integration**: Works with Gateway load balancer

### `kgateway_api.tf`
Implements Gateway API with Kgateway:
- **Gateway API CRDs**: Standard v1.2.1 implementation via kubectl
- **Kgateway CRDs**: Vendor-specific enhancements via Helm (v2.0.3)
- **Kgateway Controller**: OCI registry deployment with 15-minute timeout
- **Default Gateway**: HTTPS/HTTP listeners with TLS termination
- **Dual Architecture**: Standard + vendor-specific CRDs for portability
- **Dependencies**: Waits for Cilium upgrade completion

### `kgateway_certificate.tf`
Manages TLS certificates for the Gateway:
- **Cloudflare Origin Certificates**: Direct certificate management from local files
- **Kubernetes Secrets**: TLS certificate storage (tls.crt, tls.key)
- **Gateway Integration**: Used by default-gateway for HTTPS termination
- **Certificate Path**: Reads from ${path.module}/certs/ directory

### `cloudflare_dns.tf`
Manages DNS records in Cloudflare:
- **A Records**: Root domain and wildcard subdomain
- **Load Balancer Integration**: Points to Gateway service IP with 120s wait
- **Proxying**: Enables Cloudflare proxy for additional security
- **Dynamic IP Resolution**: Waits for load balancer IP assignment with preconditions
- **Fallback Handling**: Graceful handling of IP assignment delays

## Storage and Infrastructure Dependencies

### `csi-snapshot-crds.tf`
Installs CSI Snapshot Controller CRDs:
- **Volume Snapshots**: Enables persistent volume backup and restore
- **CRD Installation**: VolumeSnapshot, VolumeSnapshotContent, VolumeSnapshotClass
- **Dependencies**: Required before any storage operations
- **Civo Integration**: Works with Civo Cloud storage backend

### `civo-volumesnapshotclass.tf`
Configures volume snapshot capabilities:
- **Snapshot Class**: Defines snapshot parameters for Civo volumes
- **Backup Strategy**: Enables point-in-time backups for persistent storage
- **Database Support**: Critical for KubeBlocks database persistence

## Policy Engine and Governance

### `helm_kyverno.tf`
Deploys Kyverno policy engine:
- **Version**: v1.14.4 (chart v3.4.4) with admission and cleanup controllers
- **Resource Management**: 100m CPU, 256Mi memory requests; 300m CPU, 512Mi limits
- **Webhook Configuration**: Proper validating and mutating webhook setup
- **Background Scanning**: Continuous compliance checking for existing resources
- **Dependencies**: Waits for cluster readiness before deployment

### `helm_kyverno_policies.tf`
Installs pre-built Kyverno policies:
- **Pod Security Standards**: Baseline security policies for container hardening
- **Policy Collection**: 11 pre-built policies covering common security requirements
- **Namespace Exclusions**: System namespaces excluded from policy enforcement
- **Conditional Deployment**: Controlled by `enable_kyverno_policies` variable

### `kyverno_custom_policies.tf`
Implements custom cluster-specific policies:
- **Gateway API Standards**: HTTPRoute validation for proper Gateway references
- **Cilium Network Policy Governance**: Network policy annotation requirements
- **Istio Ambient Mesh Preparation**: Automatic namespace labeling for mesh inclusion
- **Cloudflare Certificate Standards**: TLS secret validation and formatting
- **Resource Requirements**: Production workload resource enforcement with exemptions

### `httproute_kyverno.tf`
Deploys Policy Reporter UI for policy management:
- **Conditional Deployment**: Basic vs full monitoring integration
- **Policy Reporter**: v2.22.0 with SQLite database for policy compliance data
- **ServiceMonitor**: Prometheus Operator integration when enabled
- **HTTPRoute**: Web UI access via Gateway API (policy-reporter.{domain})
- **Kyverno Plugin**: Essential integration for policy violation reporting

### `argo_workflows.tf`
Optionally deploys Argo Workflows for CI/CD:
- **Conditional Deployment**: Controlled by enable_argo_workflows variable (default: false)
- **Argo Workflows**: v3.6.10 (chart v0.45.19) with server auth mode
- **Argo Events**: v2.4.15 chart with JetStream EventBus
- **JetStream EventBus**: v2.10.10 with 3 replicas and persistent storage
- **HTTPRoute**: Web UI access via Gateway API (argo-workflows.{domain})
- **Storage**: Uses civo-volume storage class for persistence

## Monitoring and Observability

### `helm_prometheus_operator.tf`
Deploys comprehensive monitoring stack:
- **Prometheus Operator**: v61.9.0 kube-prometheus-stack for cloud-native monitoring
- **Components**: Prometheus server, Alertmanager, Node Exporter, kube-state-metrics
- **ServiceMonitor Support**: Automatic service discovery for metrics collection
- **Cross-namespace Monitoring**: Deployed in dedicated monitoring namespace
- **High Availability**: Resource limits and persistent storage configuration
- **Istio Integration**: ServiceMonitor for Istio control plane metrics

### `helm_metrics_server.tf`
Installs Kubernetes Metrics Server:
- **Version**: v3.12.1 for resource utilization metrics
- **HPA Support**: Horizontal Pod Autoscaler metrics source
- **Resource Monitoring**: CPU and memory usage for pods and nodes
- **Dependencies**: Core infrastructure component for cluster operations

## Helm Deployments

### `helm_cilium.tf`
Upgrades Cilium CNI with advanced networking features:
- **Version**: v1.17.5 upgrade from base installation
- **Deployment Method**: null_resource with local-exec for upgrade flexibility
- **Hubble**: Network observability and flow visualization (1h retention)
- **kube-proxy Replacement**: Enhanced networking performance
- **Ambient Mesh Compatibility**: Configured with cni.exclusive: false
- **Metrics**: DNS, drop, TCP, flow, ICMP metrics enabled

### `helm_gloo_operator.tf`
Deploys Gloo Operator for Ambient Mesh:
- **Gloo Operator**: OCI registry deployment for Istio lifecycle management
- **ServiceMeshController**: Istio v1.26.2 in Ambient mode
- **Cilium Integration**: Chained CNI configuration (cni.chained: true)
- **eBPF Traffic Redirection**: High-performance traffic handling
- **K3s Platform**: Explicitly configured for K3s compatibility
- **Ambient Configuration**: PILOT_ENABLE_AMBIENT, redirectMode: ebpf
- **Ambient Mesh**: Sidecar-less service mesh architecture
- **eBPF Integration**: High-performance traffic redirection
- **Cilium Integration**: Coordinated CNI and service mesh

### `helm_grafana.tf`
Deploys Grafana for metrics visualization:
- **Conditional Prometheus Integration**: Supports both basic and Prometheus Operator setups
- **Pre-configured Dashboards**: 10 dashboards for comprehensive monitoring
  - Kubernetes Cluster Monitoring (7249), Node Exporter Full (1860)
  - Kubernetes Pods (6417), Istio Control Plane (7645), Istio Mesh (7639)
  - Cilium Metrics (16611), Prometheus Stats (2), Kubernetes API Server (12006)
  - Kube State Metrics (13332), Alertmanager (9578)
- **Authentication**: Default admin/admin credentials
- **Namespace**: Deployed in istio-system
- **Kiali Integration**: Updates Kiali configuration for Grafana links

### `helm_kiali.tf`
Deploys Kiali for service mesh visualization:
- **Istio Integration**: Service mesh topology and health
- **Conditional Prometheus**: Supports both basic Prometheus and Prometheus Operator
- **Grafana Integration**: External Grafana dashboard links
- **Authentication**: Anonymous access for development
- **Namespace**: Deployed in istio-system
- **Gateway API Support**: Configured for Gateway API compatibility

### `helm_kubeblocks.tf`
Deploys KubeBlocks database platform:
- **Version**: v1.0.0 with separate CRD installation
- **Database Support**: PostgreSQL, Redis, MongoDB via test scripts
- **Resource Management**: 100m CPU, 256Mi memory requests; 500m CPU, 512Mi limits
- **Namespace**: Deployed in kb-system with proper labels
- **CRD Management**: Separate CRD installation with 30s wait

## Application Routing

### `httproute_grafana.tf`
Configures external access to Grafana:
- **HTTPRoute**: Gateway API routing for grafana.{domain}
- **Gateway Integration**: Uses default-gateway with TLS termination
- **Cross-namespace Access**: ReferenceGrant for service access
- **Dependencies**: Waits for Grafana deployment and Gateway availability

### `httproute_kiali.tf`
Configures external access to Kiali:
- **HTTPRoute**: Gateway API routing for kiali.{domain}
- **Service Mesh Access**: External access to Istio service mesh UI
- **Gateway Integration**: Uses default-gateway with TLS termination
- **Dependencies**: Waits for Kiali deployment and Gateway availability

## Deployment Summary

This Terraform project creates a comprehensive Kubernetes platform with:

1. **Core Infrastructure**: Civo Kubernetes cluster with Cilium CNI and CSI snapshots
2. **Modern Ingress**: Gateway API with Kgateway implementation
3. **Service Mesh**: Istio Ambient Mesh via Gloo Operator
4. **Policy Governance**: Kyverno policy engine with custom and pre-built policies
5. **Monitoring Stack**: Prometheus Operator with comprehensive Grafana dashboards
6. **Database Platform**: KubeBlocks with multiple database engines
7. **CI/CD**: Optional Argo Workflows with event-driven automation
8. **Security**: Cloudflare Origin Certificates and DNS proxying
9. **Web Interfaces**: Policy Reporter UI for policy management
10. **Storage**: CSI snapshots for backup and restore capabilities

## File Dependencies

The deployment follows this dependency order:
1. **Core Infrastructure**: cluster, firewalls, delays, storage CRDs
2. **Networking**: Cilium upgrade, Gateway API, certificates
3. **DNS Configuration**: Cloudflare DNS and load balancer integration
4. **Service Mesh**: Gloo Operator, Ambient Mesh deployment
5. **Policy Engine**: Kyverno, policies, custom governance rules
6. **Monitoring Stack**: Prometheus Operator or basic Prometheus, Metrics Server
7. **Observability**: Grafana, Kiali with conditional configurations
8. **Database Platform**: KubeBlocks with storage dependencies
9. **Policy Management**: Policy Reporter UI with monitoring integration
10. **Application Routing**: HTTPRoutes for external access
11. **Optional CI/CD**: Argo Workflows with event-driven automation

## File Organization and Dependencies

### Execution Order
1. **Foundation**: `cluster.tf`, `provider.tf` → `cluster_ready_delay.tf` → `kubectl_dependencies.tf`
2. **Storage**: `csi-snapshot-crds.tf` → `civo-volumesnapshotclass.tf`
3. **Networking**: `helm_cilium.tf` → `kgateway_api.tf` → `kgateway_certificate.tf`
4. **DNS**: `cloudflare_dns.tf` (after Gateway load balancer)
5. **Service Mesh**: `helm_gloo_operator.tf` → observability stack
6. **Policy Engine**: `helm_kyverno.tf` → `helm_kyverno_policies.tf` → `kyverno_custom_policies.tf`
7. **Monitoring**: `helm_prometheus_operator.tf` | `helm_metrics_server.tf`
8. **Observability**: `helm_grafana.tf`, `helm_kiali.tf` (conditional Prometheus integration)
9. **Database Platform**: `helm_kubeblocks.tf` (after storage and policies)
10. **Policy Management**: `httproute_kyverno.tf` (Policy Reporter with conditional monitoring)
11. **Application Routing**: `httproute_grafana.tf`, `httproute_kiali.tf`
12. **Optional Workflows**: `argo_workflows.tf` (after all core components)

### Critical Dependencies
- **All Helm charts** depend on `cluster_ready_delay.tf` and `kubectl_dependencies.tf`
- **HTTPRoutes** depend on Gateway deployment and certificate availability
- **Policy Reporter** has conditional dependencies based on monitoring stack choice
- **Service mesh components** have carefully orchestrated timing with Cilium compatibility
- **Kyverno policies** must be deployed after policy engine with proper webhook readiness
- **Monitoring stack** supports both basic and operator-based architectures

### Conditional Architecture Support
- **Prometheus**: Basic (`helm_kiali.tf` fallback) vs Operator (`helm_prometheus_operator.tf`)
- **Policy Enforcement**: Optional Kyverno deployment with policy exclusions
- **Policy Reporting**: Conditional ServiceMonitor based on monitoring stack
- **Workflow Automation**: Optional Argo Workflows deployment

This modular approach ensures reliable, repeatable infrastructure deployments with clear separation of concerns, proper dependency management, and support for both basic and advanced configurations.