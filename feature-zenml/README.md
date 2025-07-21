# ZenML Feature

This feature deploys a complete ZenML server with PostgreSQL backend and Civo Object Store for artifact storage.

## Architecture

- **Namespace**: `zenml-system` (configurable)
- **Database**: PostgreSQL via KubeBlocks operator
- **Artifact Store**: Civo Object Store bucket
- **Ingress**: Gateway API with Kgateway
- **Monitoring**: ServiceMonitor for Prometheus
- **Security**: Kyverno policy exclusions

## Components

### Core Infrastructure
- `postgres-cluster.yaml` - KubeBlocks PostgreSQL cluster
- `postgres-service-account.yaml` - ServiceAccount for PostgreSQL

### Networking
- `zenml-httproute.yaml` - HTTPRoute for external access
- `zenml-reference-grant.yaml` - Cross-namespace service access

### Monitoring & Policy
- `zenml-service-monitor.yaml` - Prometheus ServiceMonitor
- `kyverno-zenml-policy.yaml` - Updated Kyverno policies

## Configuration

Key variables:
- `enable_zenml` - Enable/disable entire feature
- `zenml_namespace` - Target namespace
- `zenml_server_version` - ZenML server version
- `zenml_artifact_bucket` - Civo Object Store bucket name
- `domain_name` - Domain for UI access

## Usage

```hcl
module "zenml" {
  source = "./feature-zenml"
  
  enable_zenml                = var.enable_zenml
  zenml_namespace            = var.zenml_namespace
  zenml_server_version       = var.zenml_server_version
  zenml_artifact_bucket      = var.zenml_artifact_bucket
  zenml_artifact_bucket_size = var.zenml_artifact_bucket_size
  domain_name               = var.domain_name
  region                    = var.region
  monitoring_namespace      = var.monitoring_namespace
  enable_prometheus_operator = var.enable_prometheus_operator
  enable_kyverno            = var.enable_kyverno
}
```

## Outputs

- `zenml_url` - ZenML UI URL
- `zenml_admin_token` - Admin access token (sensitive)
- `zenml_postgres_host` - PostgreSQL connection host
- `zenml_artifact_bucket_name` - Artifact storage bucket name
- `zenml_artifact_bucket_url` - Artifact storage bucket URL