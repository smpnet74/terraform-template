# Argo Workflows Feature - Cluster-Wide CI/CD Platform

This feature deploys Argo Workflows and Argo Events as a **cluster-wide CI/CD platform** with comprehensive RBAC, JetStream EventBus integration, and Gateway API for UI access.

## Architecture Overview

- **Deployment Scope**: **Cluster-wide** - workflows can run in any namespace
- **Control Plane Namespace**: `argo` (configurable) - houses controllers and UI
- **Workflow Engine**: Argo Workflows with cluster-wide permissions
- **Event System**: Argo Events with cluster-wide EventSource and Sensor capabilities
- **EventBus**: High-availability JetStream with 3 replicas and persistent storage
- **Ingress**: Gateway API with HTTPRoute for secure UI access
- **RBAC**: Comprehensive cluster-wide permissions for all components

## Key Cluster-Wide Capabilities

### Workflow Management
- ✅ **Run workflows in any namespace** - not limited to `argo` namespace
- ✅ **ClusterWorkflowTemplates** - reusable templates across all namespaces
- ✅ **Cross-namespace resource access** - workflows can access resources anywhere
- ✅ **Cluster-wide workflow visibility** - UI shows workflows from all namespaces

### Event Processing
- ✅ **Cluster-wide EventSources** - can watch resources in any namespace
- ✅ **Cross-namespace Sensors** - can trigger workflows in different namespaces
- ✅ **Centralized EventBus** - single event stream for entire cluster
- ✅ **High-availability event processing** - 3-replica JetStream cluster

### Security & RBAC
- ✅ **Comprehensive ClusterRoles** - proper permissions for cluster-wide operations
- ✅ **Service account isolation** - separate accounts for different components
- ✅ **Security contexts** - non-root execution with proper user/group settings
- ✅ **Network policies** - compatible with Cilium CNI

## Components

### Core Infrastructure
- `eventbus.yaml` - Enhanced JetStream EventBus with HA configuration
- `httproute.yaml` - Gateway API HTTPRoute for UI access
- `reference-grant.yaml` - ReferenceGrant for cross-namespace references
- `cluster-rbac.yaml` - **NEW**: Comprehensive cluster-wide RBAC
- `cluster-workflow-templates.yaml` - **NEW**: Common CI/CD workflow templates

### Helm Charts (Enhanced)
- **Argo Workflows**: Server and controller with cluster-wide configuration
- **Argo Events**: EventBus, EventSource, and Sensor controllers with cluster permissions

## Usage

The module is designed to be used with the root terraform.tfvars file for configuration. Key variables include:

- `enable_argo_workflows`: Toggle to enable/disable the entire cluster-wide feature
- `argo_workflows_chart_version`: Version of the Argo Workflows Helm chart
- `argo_events_chart_version`: Version of the Argo Events Helm chart
- `jetstream_version`: Version of JetStream to use for EventBus
- `argo_namespace`: Control plane namespace (default: `argo`)

## Accessing Argo Workflows

Once deployed, Argo Workflows UI is available at:
```
https://argo-workflows.<domain_name>
```

**Key UI Features:**
- View workflows from **all namespaces** (cluster-wide visibility)
- Access to ClusterWorkflowTemplates
- Submit workflows to any namespace
- Monitor cluster-wide workflow execution

## Cluster-Wide Workflow Examples

### Using ClusterWorkflowTemplates
```yaml
apiVersion: argoproj.io/v1alpha1
kind: Workflow
metadata:
  generateName: build-deploy-
  namespace: my-app-namespace  # Can be any namespace
spec:
  entrypoint: ci-cd-pipeline
  templates:
  - name: ci-cd-pipeline
    steps:
    - - name: build
        templateRef:
          name: container-build-deploy  # ClusterWorkflowTemplate
          template: build-container
          clusterScope: true
        arguments:
          parameters:
          - name: repo-url
            value: "https://github.com/myorg/myapp"
          - name: image-name
            value: "myregistry/myapp"
```

### Cross-Namespace Event Processing
```yaml
apiVersion: argoproj.io/v1alpha1
kind: EventSource
metadata:
  name: github-webhook
  namespace: argo  # EventSource in control plane
spec:
  webhook:
    github:
      port: "12000"
      endpoint: "/push"
---
apiVersion: argoproj.io/v1alpha1
kind: Sensor
metadata:
  name: github-sensor
  namespace: argo  # Sensor in control plane
spec:
  template:
    serviceAccountName: argo-events-sensor-controller
  dependencies:
  - name: github-dep
    eventSourceName: github-webhook
    eventName: github
  triggers:
  - template:
      name: github-workflow-trigger
      argoWorkflow:
        group: argoproj.io
        version: v1alpha1
        resource: workflows
        operation: create
        source:
          resource:
            apiVersion: argoproj.io/v1alpha1
            kind: Workflow
            metadata:
              generateName: github-ci-
              namespace: my-app-namespace  # Trigger workflow in different namespace
            spec:
              entrypoint: ci-pipeline
              # ... workflow definition
```

## Integration Points

- **Gateway API**: Uses the default gateway for ingress
- **Storage**: Enhanced Civo Volume configuration (20Gi) for EventBus persistence
- **Authentication**: Server auth mode with cluster-wide visibility
- **Service Mesh**: Compatible with Istio Ambient Mesh
- **Policy Engine**: Works with Kyverno governance policies
- **Monitoring**: ServiceMonitors for Prometheus integration

## Operational Commands

### Workflow Management
```bash
# List workflows across all namespaces
kubectl get workflows -A

# List cluster workflow templates
kubectl get clusterworkflowtemplates

# Submit workflow to specific namespace
argo submit workflow.yaml -n target-namespace

# Watch workflow execution
argo watch workflow-name -n target-namespace
```

### Event System Management
```bash
# Check EventBus status
kubectl get eventbus -n argo

# List EventSources and Sensors
kubectl get eventsources,sensors -n argo

# Monitor event processing
kubectl logs -f deployment/eventsource-controller -n argo
kubectl logs -f deployment/sensor-controller -n argo
```

### Troubleshooting
```bash
# Check controller logs
kubectl logs -f deployment/workflow-controller -n argo
kubectl logs -f deployment/argo-server -n argo

# Verify cluster-wide permissions
kubectl auth can-i create workflows --as=system:serviceaccount:argo:argo-workflow-controller -A

# Check EventBus health
kubectl get pods -l app.kubernetes.io/component=eventbus -n argo
```

## Cleanup

All resources are managed by Terraform and will be properly cleaned up during `terraform destroy`. This includes:
- Cluster-wide RBAC resources
- ClusterWorkflowTemplates
- EventBus persistent volumes
- All namespace-scoped resources
