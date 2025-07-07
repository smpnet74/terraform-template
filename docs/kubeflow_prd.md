# Kubeflow Integration PRD (Product Requirements Document)

## 1. Introduction

### 1.1 Purpose
This document outlines the plan for integrating Kubeflow into the existing Kubernetes cluster using GitOps principles with ArgoCD. The implementation will leverage the existing infrastructure components, including kgateway for ingress and ambient mesh for service mesh capabilities.

### 1.2 Scope
The scope of this integration includes:
- Deploying core Kubeflow components via ArgoCD
- Configuring Kubeflow to work with kgateway for ingress
- Ensuring compatibility with ambient mesh
- Setting up the GitOps repository structure for long-term management
- Providing a foundation for future extensions (KServe, Elyra, etc.)

### 1.3 Background
The existing cluster includes:
- ArgoCD for GitOps-based deployment
- kgateway for ingress management
- Ambient mesh for service mesh capabilities
- A GitOps repository for configuration management

Kubeflow will be integrated into this environment to provide machine learning capabilities while maintaining the GitOps workflow.

## 2. Requirements

### 2.1 Functional Requirements
1. Deploy core Kubeflow components using ArgoCD
2. Configure ingress through kgateway
3. Ensure compatibility with ambient mesh
4. Maintain GitOps workflow for all configurations
5. Support future extensions for ML workflows

### 2.2 Non-Functional Requirements
1. Minimize resource overhead
2. Ensure security best practices
3. Maintain scalability
4. Support upgradability through GitOps
5. Provide documentation for the integration

### 2.3 Constraints
1. Must use the existing GitOps repository
2. Must work with the existing kgateway and ambient mesh
3. Initial deployment should focus on core components only
4. Must follow Kubernetes best practices

## 3. Architecture

### 3.1 GitOps Repository Structure

The GitOps repository will be organized as follows to support Kubeflow integration:

```
k8s-app-configs/
├── apps/
│   ├── nginx.yaml
│   ├── bookinfo.yaml
│   └── kubeflow.yaml  # ArgoCD Application for Kubeflow
└── kubeflow/
    ├── base/
    │   ├── kustomization.yaml  # References upstream Kubeflow manifests
    │   └── namespace.yaml      # Kubeflow namespace definition
    ├── overlays/
    │   └── default/
    │       ├── kustomization.yaml  # Customizations for environment
    │       ├── gateway-config.yaml # kgateway integration
    │       └── patches/            # Patches for ambient mesh integration
    └── profiles/                   # User profiles configuration
```

### 3.2 Component Integration

#### 3.2.1 Kubeflow Core Components
The initial deployment will include these core Kubeflow components:
- Central Dashboard
- Notebook Controller
- Jupyter Web App
- Profiles/Multi-user isolation
- Volumes Web App
- Tensorboard Web App & Controller
- Admission Webhook
- User Namespace

#### 3.2.2 Integration with kgateway
Kubeflow will be exposed through kgateway using HTTPRoute resources, directing traffic to the Kubeflow internal istio-ingressgateway service.

#### 3.2.3 Integration with Ambient Mesh
Kubeflow will be configured to work with ambient mesh by:
- Disabling Istio sidecar injection
- Enabling ambient mesh mode via namespace labels
- Configuring appropriate service annotations

### 3.3 Deployment Flow

1. Create Kubeflow namespace and CRDs
2. Deploy core Kubeflow components via ArgoCD
3. Configure kgateway integration
4. Configure ambient mesh integration
5. Validate deployment

## 4. Implementation Plan

### 4.1 Terraform Configuration

Two main Terraform files will be created/modified:

#### 4.1.1 github_kubeflow.tf
This file will manage the Kubeflow manifests in the GitOps repository, including:
- Base kustomization referencing upstream Kubeflow manifests
- Overlay kustomization with customizations
- Gateway configuration for kgateway integration
- Patches for ambient mesh integration
- ArgoCD Application definition

#### 4.1.2 argocd_applications.tf
This file will be updated to include:
- Kubeflow Application in ArgoCD
- DNS record for Kubeflow
- HTTPRoute for kgateway integration

### 4.2 Implementation Steps

#### 4.2.1 Phase 1: Repository Setup
1. Create the directory structure in the GitOps repository
2. Add base kustomization referencing upstream Kubeflow manifests
3. Create overlay kustomization with initial customizations
4. Add gateway configuration for kgateway integration
5. Add patches for ambient mesh integration

#### 4.2.2 Phase 2: ArgoCD Integration
1. Create the Kubeflow Application in ArgoCD
2. Configure synchronization policy and retry options
3. Set up dependencies to ensure proper deployment order
4. Add DNS record for Kubeflow

#### 4.2.3 Phase 3: Validation and Testing
1. Verify Kubeflow components are deployed successfully
2. Test access through kgateway
3. Validate ambient mesh integration
4. Test core functionality (notebooks, dashboards, etc.)

## 5. Technical Details

### 5.1 Kubeflow Manifests

The implementation will use the official Kubeflow manifests from the [kubeflow/manifests](https://github.com/kubeflow/manifests) repository. These manifests are kustomize-based and provide a modular approach to deploying Kubeflow components.

### 5.2 Key Configuration Files

#### 5.2.1 Base Kustomization
```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
- github.com/kubeflow/manifests/common/kubeflow-namespace/base
- github.com/kubeflow/manifests/common/kubeflow-roles/base
- github.com/kubeflow/manifests/common/istio-1-17/kubeflow-istio-resources/base
- github.com/kubeflow/manifests/apps/centraldashboard/upstream/overlays/istio
- github.com/kubeflow/manifests/apps/jupyter/notebook-controller/upstream/overlays/kubeflow
- github.com/kubeflow/manifests/apps/jupyter/jupyter-web-app/upstream/overlays/istio
- github.com/kubeflow/manifests/apps/profiles/upstream/overlays/kubeflow
- github.com/kubeflow/manifests/apps/volumes-web-app/upstream/overlays/istio
- github.com/kubeflow/manifests/apps/tensorboard/tensorboards-web-app/upstream/overlays/istio
- github.com/kubeflow/manifests/apps/tensorboard/tensorboard-controller/upstream/overlays/kubeflow
- github.com/kubeflow/manifests/apps/admission-webhook/upstream/overlays/cert-manager
- github.com/kubeflow/manifests/apps/user-namespace/upstream/base
```

#### 5.2.2 Gateway Configuration
```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: kubeflow-route
  namespace: kubeflow
spec:
  parentRefs:
  - name: default-gateway
    namespace: default
    kind: Gateway
  hostnames:
  - "kubeflow.example.com"
  rules:
  - matches:
    - path:
        type: PathPrefix
        value: /
    backendRefs:
    - name: istio-ingressgateway
      namespace: kubeflow
      port: 80
```

#### 5.2.3 Ambient Mesh Configuration
```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: kubeflow
  labels:
    istio-injection: "disabled"  # Disable Istio sidecar injection
    istio.io/dataplane-mode: "ambient"  # Enable ambient mesh mode
```

### 5.3 Resource Requirements

Kubeflow components have the following approximate resource requirements:

| Component | CPU Request | Memory Request | CPU Limit | Memory Limit |
|-----------|------------|----------------|-----------|-------------|
| Central Dashboard | 100m | 256Mi | 500m | 512Mi |
| Notebook Controller | 100m | 256Mi | 500m | 512Mi |
| Jupyter Web App | 100m | 256Mi | 500m | 512Mi |
| Profiles | 100m | 256Mi | 500m | 512Mi |
| Volumes Web App | 100m | 256Mi | 500m | 512Mi |
| Tensorboard Web App | 100m | 256Mi | 500m | 512Mi |
| Tensorboard Controller | 100m | 256Mi | 500m | 512Mi |
| Admission Webhook | 100m | 256Mi | 500m | 512Mi |

Total estimated resource requirements for core components:
- CPU: ~1 core (requests), ~4 cores (limits)
- Memory: ~2GB (requests), ~4GB (limits)

## 6. Future Enhancements

### 6.1 Additional Components

After the core Kubeflow installation is stable, the following components can be added:

1. **KServe** - For model serving capabilities
   - Add KServe controller and CRDs
   - Configure integration with ambient mesh
   - Set up model storage with appropriate PVCs

2. **Kubeflow Pipelines** - For ML workflow orchestration
   - Add pipeline components and CRDs
   - Configure artifact storage
   - Set up integration with notebooks

3. **Katib** - For hyperparameter tuning
   - Add Katib controller and CRDs
   - Configure integration with pipelines

4. **Elyra** - For notebook-based pipelines
   - Add Elyra components
   - Configure integration with Kubeflow Pipelines

### 6.2 Advanced Configuration

Future enhancements to the configuration may include:

1. **Authentication Integration**
   - OIDC/OAuth2 integration
   - Role-based access control refinements

2. **Resource Optimization**
   - Node selectors for ML workloads
   - Autoscaling configurations
   - GPU/TPU integration

3. **Monitoring and Logging**
   - Prometheus integration for metrics
   - Grafana dashboards for Kubeflow components
   - Centralized logging

4. **Backup and Disaster Recovery**
   - Backup procedures for Kubeflow metadata
   - Disaster recovery planning

### 6.3 GitOps Enhancements

1. **Automated Testing**
   - CI/CD pipeline for testing Kubeflow configurations
   - Validation hooks for GitOps changes

2. **Progressive Delivery**
   - Canary deployments for Kubeflow updates
   - Blue/green deployment strategies
