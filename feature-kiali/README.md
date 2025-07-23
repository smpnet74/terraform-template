# Kiali Service Mesh Observability Feature Module

This module deploys Kiali, a service mesh observability dashboard for Istio, providing visualization and management of service mesh components.

## Components

### Core Components
- **Kiali Server**: Service mesh observability dashboard
- **HTTPRoute Configuration**: External access via Gateway API
- **Prometheus Integration**: Flexible monitoring backend support
- **Grafana Integration**: Dashboard and visualization integration

### Conditional Components
- **Basic Prometheus**: Deployed only when Prometheus Operator is disabled
- **Prometheus Wait Resources**: Ensures proper startup order for basic Prometheus

## Configuration

### Authentication
- **Strategy**: Anonymous access (no authentication required)
- **Ingress**: Disabled (using Gateway API instead)

### External Service Integrations

#### Prometheus Integration
- **Prometheus Operator Mode**: Uses `kube-prometheus-stack-prometheus` in monitoring namespace
- **Basic Mode**: Uses local `prometheus-server` in istio-system namespace
- **Automatic Detection**: Switches based on `enable_prometheus_operator` variable

#### Grafana Integration
- **Enabled**: Automatic integration with Grafana service
- **URL**: `http://grafana.istio-system:80`
- **Cross-service**: Links to Grafana dashboards from Kiali UI

#### Istio Integration
- **Gateway API Support**: Configured for `gateway.networking.k8s.io/v1`
- **Service Mesh Discovery**: Automatic detection of Istio components
- **Namespace**: Deployed in `istio-system` alongside service mesh

## Basic Prometheus (Fallback Mode)

When Prometheus Operator is not enabled, deploys a minimal Prometheus instance:

### Configuration
- **Persistent Storage**: Disabled (ephemeral volumes)
- **Alertmanager**: Disabled (not needed for basic metrics)
- **Pushgateway**: Disabled (not needed for service mesh)
- **Namespace**: `istio-system` (co-located with Kiali)

### Purpose
Provides essential metrics collection for Kiali when full monitoring stack is not available.

## Network Access

### External Access
- **URL**: `https://kiali.{domain_name}`
- **Protocol**: HTTPS with Cloudflare Origin Certificates
- **Routing**: HTTPRoute via default Gateway

### Local Development
```bash
kubectl port-forward svc/kiali -n istio-system 20001:20001
# Access at http://localhost:20001
```

## Service Mesh Features

### Supported Visualizations
- **Service Graph**: Real-time service topology
- **Traffic Flow**: Request rates, response times, error rates
- **Security Policies**: mTLS status and security configurations
- **Configuration Validation**: Istio configuration issues

### Gateway API Integration
- **Modern Routing**: Uses Gateway API v1 for ingress
- **Cross-namespace Access**: ReferenceGrant support via default Gateway
- **TLS Termination**: Automatic HTTPS with Cloudflare certificates

## Dependencies

### Required Infrastructure
- **Istio Service Mesh**: Service mesh controller must be deployed
- **Gateway API**: Default Gateway must be available
- **DNS Resolution**: Domain configuration for external access

### Optional Dependencies
- **Prometheus Operator**: Enhanced monitoring when available
- **Grafana**: Dashboard integration and visualization links

## Monitoring Integration

### With Prometheus Operator
- **ServiceMonitor**: Automatic metrics discovery
- **Advanced Queries**: Full PromQL support
- **Historical Data**: Persistent storage for trend analysis

### With Basic Prometheus
- **Essential Metrics**: Core service mesh metrics only
- **Ephemeral Storage**: Metrics reset on pod restart
- **Limited History**: Short-term metrics retention

## Variables

- `enable_prometheus_operator`: Determines monitoring backend (Prometheus Operator vs basic Prometheus)
- `monitoring_namespace`: Namespace for Prometheus Operator integration
- `domain_name`: Domain for external HTTPRoute configuration

## Security Considerations

- **Anonymous Access**: No authentication configured (suitable for internal clusters)
- **Network Policies**: Consider restricting access in production environments
- **TLS Encryption**: All external traffic encrypted via Cloudflare Origin Certificates