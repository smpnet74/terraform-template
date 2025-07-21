# Argo Workflows Feature

This feature deploys Argo Workflows and Argo Events with JetStream EventBus integration and Gateway API for UI access.

## Architecture

- **Namespace**: `argo` (configurable)
- **Workflow Engine**: Argo Workflows
- **Event System**: Argo Events with JetStream EventBus
- **Ingress**: Gateway API with HTTPRoute
- **Storage**: Persistent storage for EventBus using Civo Volume

## Components

### Core Infrastructure
- `eventbus.yaml` - JetStream EventBus configuration
- `httproute.yaml` - Gateway API HTTPRoute for UI access
- `reference-grant.yaml` - ReferenceGrant for cross-namespace references

### Helm Charts
- **Argo Workflows**: Server and controller components
- **Argo Events**: EventBus, EventSource, and Sensor controllers

## Usage

The module is designed to be used with the root terraform.tfvars file for configuration. Key variables include:

- `enable_argo_workflows`: Toggle to enable/disable the entire feature
- `argo_workflows_chart_version`: Version of the Argo Workflows Helm chart
- `argo_events_chart_version`: Version of the Argo Events Helm chart
- `jetstream_version`: Version of JetStream to use for EventBus

## Accessing Argo Workflows

Once deployed, Argo Workflows UI is available at:
```
https://argo-workflows.<domain_name>
```

## Integration Points

- **Gateway API**: Uses the default gateway for ingress
- **Storage**: Uses Civo Volume for EventBus persistence
- **Authentication**: Uses server auth mode (can be customized)

## Cleanup

All resources are managed by Terraform and will be properly cleaned up during `terraform destroy`.
