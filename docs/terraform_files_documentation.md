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
- **Feature Toggles**: Enable/disable Argo Workflows (default: false)
- **Version Control**: Pinned versions for Argo Workflows (v0.45.19), Argo Events (v2.4.15), JetStream (v2.10.10), Metrics Server (v3.12.1)

### `outputs.tf`
Defines output values displayed after deployment:
- **Access URLs**: Kiali, Grafana, Argo Workflows endpoints
- **Access Commands**: Hubble UI, Kiali port-forward, Civo kubeconfig commands
- **Platform Information**: KubeBlocks usage instructions and test scripts
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

## GitOps and CI/CD

### `github.tf`
Creates and configures the GitOps repository:
- **Repository Creation**: Automated GitHub repo setup
- **Initial Structure**: Basic GitOps directory layout
- **ArgoCD Integration**: Repository connection for continuous deployment

### `argocd_applications.tf`
Defines the root ArgoCD application using app-of-apps pattern:
- **Root Application**: Manages all other applications
- **GitOps Repository**: Syncs from created GitHub repo
- **Automatic Sync**: Continuous deployment of applications
- **Self-healing**: Automatic drift correction

### `argocd_bookinfo.tf`
Configures the Bookinfo sample application module:
- **Conditional Deployment**: Controlled by `enable_bookinfo` variable
- **Module Integration**: Uses `modules/bookinfo/` for deployment
- **ArgoCD Management**: Deployed through GitOps workflow

### `argo_workflows.tf`
Optionally deploys Argo Workflows for CI/CD:
- **Conditional Deployment**: Controlled by enable_argo_workflows variable (default: false)
- **Argo Workflows**: v3.6.10 (chart v0.45.19) with server auth mode
- **Argo Events**: v2.4.15 chart with JetStream EventBus
- **JetStream EventBus**: v2.10.10 with 3 replicas and persistent storage
- **HTTPRoute**: Web UI access via Gateway API (argo-workflows.{domain})
- **Storage**: Uses civo-volume storage class for persistence

## Helm Deployments

### `helm_argocd.tf`
Installs and configures ArgoCD using Helm:
- **GitOps Controller**: Core continuous deployment platform
- **GitHub Integration**: Repository synchronization
- **Web Interface**: Management UI and API access
- **RBAC Configuration**: Secure access controls

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
- **Prometheus Integration**: Configured data source (http://prometheus-server)
- **Dashboard Providers**: Istio and system dashboards
- **Authentication**: Default admin/admin credentials
- **Namespace**: Deployed in istio-system
- **Kiali Integration**: Updates Kiali configuration for Grafana links

### `helm_kiali.tf`
Deploys Kiali for service mesh visualization:
- **Istio Integration**: Service mesh topology and health
- **Grafana Integration**: External Grafana dashboard links
- **Authentication**: Anonymous access for development
- **Namespace**: Deployed in istio-system
- **Prometheus**: Configured for metrics collection

### `helm_kubeblocks.tf`
Deploys KubeBlocks database platform:
- **Version**: v1.0.0 with separate CRD installation
- **Database Support**: PostgreSQL, Redis, MongoDB via test scripts
- **Resource Management**: 100m CPU, 256Mi memory requests; 500m CPU, 512Mi limits
- **Namespace**: Deployed in kb-system with proper labels
- **CRD Management**: Separate CRD installation with 30s wait

## Deployment Summary

This Terraform project creates a comprehensive Kubernetes platform with:

1. **Core Infrastructure**: Civo Kubernetes cluster with Cilium CNI
2. **Modern Ingress**: Gateway API with Kgateway implementation
3. **Service Mesh**: Istio Ambient Mesh via Gloo Operator
4. **Observability**: Grafana, Kiali, Hubble UI for monitoring
5. **Database Platform**: KubeBlocks with multiple database engines
6. **CI/CD**: Optional Argo Workflows with event-driven automation
7. **Security**: Cloudflare Origin Certificates and DNS proxying
8. **Storage**: CSI snapshots for backup and restore capabilities

## File Dependencies

The deployment follows this dependency order:
1. Core infrastructure (cluster, firewalls, delays)
2. Networking (Cilium upgrade, Gateway API)
3. Certificates and DNS configuration
4. Service mesh (Gloo Operator, Ambient Mesh)
5. Observability stack (Grafana, Kiali, Prometheus)
6. Database platform (KubeBlocks)
7. Optional CI/CD (Argo Workflows)
8. Application routing (HTTPRoutes)

All files are designed to work together as a cohesive infrastructure deployment with proper dependency management and error handling.
- **Service Mesh Demo**: Showcases Ambient Mesh capabilities
- **HTTPRoute**: External access configuration
- **ArgoCD Integration**: GitOps-managed deployment

## File Organization and Dependencies

### Execution Order
1. **Foundation**: `cluster.tf`, `provider.tf` → `cluster_ready_delay.tf`
2. **Networking**: `helm_cilium.tf` → `kgateway_api.tf` → `kgateway_certificate.tf`
3. **DNS**: `cloudflare_dns.tf` (after Gateway load balancer)
4. **Service Mesh**: `helm_gloo_operator.tf` → observability stack
5. **GitOps**: `github.tf` → `helm_argocd.tf` → applications
6. **Storage**: `csi-snapshot-crds.tf` → `civo-volumesnapshotclass.tf` → `helm_kubeblocks.tf`
7. **CI/CD**: `argo_workflows.tf` (optional, after ArgoCD)

### Critical Dependencies
- All Helm charts depend on `cluster_ready_delay.tf`
- HTTPRoutes depend on Gateway deployment and certificate availability
- Service mesh components have carefully orchestrated timing
- GitOps applications require GitHub repository and ArgoCD installation

This modular approach ensures reliable, repeatable infrastructure deployments with clear separation of concerns and proper dependency management.