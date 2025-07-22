# Prometheus Operator Module

This module deploys the kube-prometheus-stack, providing cloud-native monitoring for Kubernetes with Prometheus, Alertmanager, and related components.

## Components

### Core Stack
- **Prometheus Operator**: Manages Prometheus instances using CRDs
- **Prometheus Server**: Time-series database and monitoring system
- **Alertmanager**: Alert routing and notification management
- **Node Exporter**: System metrics collection from cluster nodes
- **kube-state-metrics**: Kubernetes object metrics collection

### Service Discovery
- **ServiceMonitor CRDs**: Automatic service discovery for monitoring targets
- **PrometheusRule CRDs**: Declarative alerting and recording rules
- **Cross-namespace monitoring**: Discovers services across all namespaces

## Included ServiceMonitors

### Istio Control Plane (`istio-control-plane-servicemonitor.yaml`)
- Monitors istiod-gloo service in istio-system namespace
- Collects control plane metrics via `/stats/prometheus` endpoint
- 30-second scrape interval

### Cilium CNI (`cilium-servicemonitor.yaml`) 
- Monitors Cilium agents in kube-system namespace
- Collects network policy and connectivity metrics
- 30-second scrape interval

### Kgateway (`kgateway-servicemonitor.yaml`)
- Monitors Gateway API controller in kgateway-system namespace
- Collects gateway and routing metrics
- 30-second scrape interval

## Configuration

### Resource Allocation
- **Prometheus Server**: 200m-1000m CPU, 512Mi-2Gi memory, 10Gi storage
- **Alertmanager**: 50m-200m CPU, 128Mi-256Mi memory, 2Gi storage
- **Prometheus Operator**: 50m-200m CPU, 128Mi-256Mi memory

### Storage Configuration
- Uses persistent volumes for data retention
- Prometheus: 7-day retention, 8GiB size limit
- Alertmanager: 2Gi persistent storage

### Security
- All components run as non-root (UID 1000)
- Security contexts applied to all workloads
- RBAC permissions for service discovery

## Integration Points

### External Grafana
- Built-in Grafana is disabled (`grafana.enabled: false`)
- Uses external Grafana in istio-system namespace
- Prometheus configured as primary datasource

### Policy Reporter
- ServiceMonitor automatically created when Policy Reporter UI is enabled
- Integrates with kube-prometheus-stack for policy violation metrics

### Managed Cluster Optimizations
- Disables monitoring for inaccessible components (etcd, controller-manager, scheduler)
- Optimized for Civo managed Kubernetes clusters
- Compatible with Cilium CNI (kubeProxy disabled)

## Access Methods

### Port Forwarding
```bash
# Prometheus UI
kubectl port-forward svc/kube-prometheus-stack-prometheus -n monitoring 9090:9090

# Alertmanager UI  
kubectl port-forward svc/kube-prometheus-stack-alertmanager -n monitoring 9093:9093
```

### Management Commands
```bash
# View discovered services
kubectl get servicemonitors -A

# View alerting rules
kubectl get prometheusrules -A

# Check Prometheus configuration
kubectl get prometheus -n monitoring -o yaml
```

## Dependencies

- Kubernetes cluster with sufficient resources
- Storage class for persistent volumes
- Network connectivity for service discovery across namespaces

## Variables

- `enable_prometheus_operator`: Enable/disable the monitoring stack
- `prometheus_operator_chart_version`: Helm chart version to deploy
- `monitoring_namespace`: Target namespace (default: monitoring)