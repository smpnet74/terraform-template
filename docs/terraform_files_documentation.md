# Terraform Files Documentation

This document provides a comprehensive overview of all Terraform files in this project and explains their purpose, dependencies, and role in the infrastructure deployment.

## Core Infrastructure

### `provider.tf`
Configures the Terraform providers used in the project, including:
- **Civo**: Kubernetes cluster management
- **Kubernetes**: Resource management within the cluster
- **Helm**: Chart deployments
- **kubectl**: Custom resource management
- **Cloudflare**: DNS and certificate management
- **GitHub**: Repository management for GitOps
- **time**: Deployment delays and timing

### `cluster.tf`
Creates and configures the Civo Kubernetes cluster with:
- **Cluster Configuration**: 3-node cluster with configurable instance types
- **Cilium CNI**: Network layer with Ambient Mesh compatibility
- **Kubeconfig Generation**: Local cluster access configuration
- **Dependencies**: Core foundation for all other resources

### `io.tf`
Defines all input variables for the Terraform project, including:
- **Infrastructure Variables**: Cluster size, region, node configuration
- **Networking Variables**: Firewall rules, domain configuration
- **Integration Variables**: GitHub, Cloudflare API tokens
- **Feature Toggles**: Enable/disable optional components
- **Version Control**: Pinned versions for Argo Workflows and Events

### `outputs.tf`
Defines output values displayed after deployment:
- **Access URLs**: All application endpoints (ArgoCD, Grafana, Kiali, etc.)
- **Access Commands**: Credential retrieval and configuration commands
- **Platform Information**: Usage instructions and important notes

### `cluster_ready_delay.tf`
Implements timing controls to ensure cluster readiness:
- **60-second delay** after cluster creation
- **Ensures CNI stability** before deploying workloads
- **Critical for reliable deployments**

## Networking and Security

### `civo_firewall-cluster.tf`
Configures Civo firewall rules for cluster API access:
- **Port 6443**: Kubernetes API server access
- **Configurable CIDR blocks**: Control API access from specific networks
- **Security**: Restricts cluster management access

### `civo_firewall-ingress.tf`
Sets up firewall rules for application traffic:
- **Port 80**: HTTP traffic to Gateway load balancer
- **Port 443**: HTTPS traffic to Gateway load balancer
- **Public Access**: Configurable for internet or restricted access

### `cloudflare_dns.tf`
Manages DNS records pointing to the Gateway:
- **Root Domain**: Points to Gateway load balancer IP
- **Wildcard Record**: `*.domain.com` for subdomain routing
- **Proxying Enabled**: DDoS protection and edge acceleration
- **Dynamic IP**: Automatically updates when Gateway IP changes

### `kgateway_api.tf`
Installs and configures modern ingress using Gateway API:
- **Gateway API CRDs**: v1.2.1 standard installation
- **Kgateway Implementation**: v2.0.3 with OCI chart deployment
- **Default Gateway**: HTTP (80) and HTTPS (443) listeners
- **Cross-namespace Access**: Allows HTTPRoutes from all namespaces

### `kgateway_certificate.tf`
Manages TLS certificates for secure communication:
- **Cloudflare Origin Certificates**: Direct certificate management
- **Kubernetes Secret**: Stores certificate and private key
- **TLS Termination**: Gateway-level SSL/TLS handling
- **No cert-manager**: Simplified certificate management

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
Deploys in-cluster CI/CD pipeline capabilities:
- **Argo Workflows**: Container build and deployment automation
- **Argo Events**: EventSources and Sensors for workflow triggers
- **EventBus**: JetStream-based event communication
- **Kaniko Integration**: In-cluster container image builds
- **Version Control**: Pinned chart versions for stability
- **HTTPRoute**: Web interface access via Gateway
- **ReferenceGrant**: Cross-namespace access permissions

## Helm Deployments

### `helm_argocd.tf`
Installs and configures ArgoCD using Helm:
- **GitOps Controller**: Core continuous deployment platform
- **GitHub Integration**: Repository synchronization
- **Web Interface**: Management UI and API access
- **RBAC Configuration**: Secure access controls

### `helm_cilium.tf`
Upgrades Cilium CNI with advanced networking features:
- **CNI Upgrade**: From basic to advanced Cilium features
- **Hubble Observability**: Network traffic visualization
- **Ambient Mesh Compatibility**: CNI chaining for service mesh
- **Network Policies**: Advanced security controls

### `helm_gloo_operator.tf`
Installs Gloo Operator for Istio Ambient Mesh:
- **Service Mesh Controller**: Deploys Istio control plane
- **Ambient Mesh**: Sidecar-less service mesh architecture
- **eBPF Integration**: High-performance traffic redirection
- **Cilium Integration**: Coordinated CNI and service mesh

### `helm_grafana.tf`
Deploys Grafana for monitoring and visualization:
- **Monitoring Dashboard**: Metrics visualization platform
- **Prometheus Integration**: Data source configuration
- **Custom Dashboards**: Pre-configured monitoring views
- **Persistent Storage**: Dashboard and configuration persistence

### `helm_kiali.tf`
Deploys Kiali for service mesh observability:
- **Service Mesh Console**: Topology and traffic visualization
- **Prometheus Deployment**: Metrics collection for Kiali
- **Istio Integration**: Service mesh monitoring and management
- **Security Analysis**: mTLS and security policy visualization

### `helm_kubeblocks.tf`
Installs KubeBlocks for database management:
- **Database Platform**: Cloud-native database operations
- **Multiple Engines**: PostgreSQL, Redis, MongoDB support
- **Backup/Restore**: Automated database lifecycle management
- **High Availability**: Multi-replica database configurations

## Application Routing

### `httproute_argocd.tf`
Configures external access to ArgoCD:
- **Gateway Integration**: Routes traffic through Kgateway
- **TLS Termination**: HTTPS access with Cloudflare certificates
- **Path-based Routing**: `/` prefix for ArgoCD interface
- **Cross-namespace**: Routes from `argocd` to `default` gateway

### `httproute_grafana.tf`
Configures external access to Grafana:
- **Monitoring Access**: Web-based dashboard access
- **Secure Routing**: HTTPS with certificate management
- **Service Integration**: Routes to Grafana service in `istio-system`

### `httproute_kiali.tf`
Configures external access to Kiali:
- **Service Mesh Console**: Web-based service mesh management
- **Observability Access**: External access to mesh topology
- **Secure Communication**: HTTPS routing with TLS termination

## Storage and Database Support

### `csi-snapshot-crds.tf`
Installs Container Storage Interface snapshot capabilities:
- **Volume Snapshots**: Database backup functionality
- **CRD Installation**: Custom Resource Definitions for snapshots
- **KubeBlocks Integration**: Required for database backup/restore

### `civo-volumesnapshotclass.tf`
Configures Civo-specific volume snapshot capabilities:
- **Civo Storage**: Cloud provider specific snapshot configuration
- **Backup Strategy**: Enables automated database backups
- **Storage Class**: Default snapshot behavior for volumes

## Dependency and Resource Management

### `kubectl_dependencies.tf`
Manages kubectl provider configuration and dependencies:
- **Provider Configuration**: kubectl access to cluster
- **Resource Dependencies**: Ensures proper deployment order
- **Custom Resources**: Manages CRDs and complex Kubernetes resources

## Modules

### `modules/bookinfo/`
Modular deployment of Istio's sample application:
- **Microservices**: 4-service sample application
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