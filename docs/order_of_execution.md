# Terraform Execution Order

This document provides a visual representation of the deployment order for Terraform components in the project.

## Deployment Flow

```
┌─────────────────────────────────────────────────────────────┐
│                    Phase 1: Foundation                     │
├─────────────────────────────────────────────────────────────┤
│ 1. provider.tf           → Terraform providers setup       │
│ 2. civo_firewall-*.tf    → Firewall rules (API + ingress) │
│ 3. cluster.tf            → Kubernetes cluster + kubeconfig │
│ 4. cluster_ready_delay.tf → 60s wait for API server       │
│ 5. kubectl_dependencies.tf → kubectl provider config      │
└─────────────────────────────────────────────────────────────┘
                                │
                                ▼
┌─────────────────────────────────────────────────────────────┐
│                 Phase 2: Storage & Dependencies            │
├─────────────────────────────────────────────────────────────┤
│ 6. csi-snapshot-crds.tf   → Volume snapshot CRDs          │
│ 7. civo-volumesnapshotclass.tf → Snapshot storage class   │
└─────────────────────────────────────────────────────────────┘
                                │
                                ▼
┌─────────────────────────────────────────────────────────────┐
│                   Phase 3: Core Networking                 │
├─────────────────────────────────────────────────────────────┤
│ 8. helm_cilium.tf         → Cilium CNI v1.17.5 upgrade    │
│ 9. kgateway_api.tf        → Gateway API CRDs + Kgateway   │
│10. kgateway_certificate.tf → Cloudflare Origin Cert       │
│11. cloudflare_dns.tf      → DNS A records (root + *)      │
└─────────────────────────────────────────────────────────────┘
                                │
                                ▼
┌─────────────────────────────────────────────────────────────┐
│                   Phase 4: Service Mesh                    │
├─────────────────────────────────────────────────────────────┤
│12. helm_gloo_operator.tf  → Istio Ambient Mesh v1.26.2    │
└─────────────────────────────────────────────────────────────┘
                                │
                                ▼
┌─────────────────────────────────────────────────────────────┐
│                 Phase 5: Policy & Governance               │
├─────────────────────────────────────────────────────────────┤
│13. helm_kyverno.tf        → Kyverno v1.14.4 policy engine │
│14. helm_kyverno_policies.tf → Pre-built security policies │
│15. kyverno_custom_policies.tf → 5 custom cluster policies │
└─────────────────────────────────────────────────────────────┘
                                │
                                ▼
┌─────────────────────────────────────────────────────────────┐
│                 Phase 6: Monitoring Stack                  │
├─────────────────────────────────────────────────────────────┤
│16. helm_prometheus_operator.tf → Prometheus Operator stack │
│17. helm_metrics_server.tf → Kubernetes Metrics Server     │
└─────────────────────────────────────────────────────────────┘
                                │
                                ▼
┌─────────────────────────────────────────────────────────────┐
│                Phase 7: Observability & UI                 │
├─────────────────────────────────────────────────────────────┤
│18. helm_grafana.tf        → Grafana + 10 dashboards       │
│19. helm_kiali.tf          → Kiali service mesh UI         │
│20. httproute_kyverno.tf   → Policy Reporter UI            │
└─────────────────────────────────────────────────────────────┘
                                │
                                ▼
┌─────────────────────────────────────────────────────────────┐
│                 Phase 8: Database Platform                 │
├─────────────────────────────────────────────────────────────┤
│21. helm_kubeblocks.tf     → KubeBlocks operator v1.0.0    │
└─────────────────────────────────────────────────────────────┘
                                │
                                ▼
┌─────────────────────────────────────────────────────────────┐
│                Phase 9: Application Routing                │
├─────────────────────────────────────────────────────────────┤
│22. httproute_grafana.tf   → External Grafana access       │
│23. httproute_kiali.tf     → External Kiali access         │
└─────────────────────────────────────────────────────────────┘
                                │
                                ▼
┌─────────────────────────────────────────────────────────────┐
│              Phase 10: Optional CI/CD (if enabled)         │
├─────────────────────────────────────────────────────────────┤
│24. argo_workflows.tf      → Argo Workflows + Events       │
└─────────────────────────────────────────────────────────────┘
```

## Component Versions

| Category | Component | Version | File |
|----------|-----------|---------|------|
| **Infrastructure** | Kubernetes | 1.30.5-k3s1 | `cluster.tf` |
| | Cilium CNI | v1.17.5 | `helm_cilium.tf` |
| | Gateway API | v1.2.1 | `kgateway_api.tf` |
| | Kgateway | v2.0.3 | `kgateway_api.tf` |
| **Service Mesh** | Istio Ambient | v1.26.2 | `helm_gloo_operator.tf` |
| **Policy** | Kyverno | v1.14.4 | `helm_kyverno.tf` |
| | Policy Reporter | v2.22.0 | `httproute_kyverno.tf` |
| **Monitoring** | Prometheus Operator | v61.9.0 | `helm_prometheus_operator.tf` |
| | Metrics Server | v3.12.1 | `helm_metrics_server.tf` |
| **Database** | KubeBlocks | v1.0.0 | `helm_kubeblocks.tf` |
| **CI/CD** | Argo Workflows | v0.45.19 | `argo_workflows.tf` |
| | Argo Events | v2.4.15 | `argo_workflows.tf` |

## Critical Dependencies

### **Wait Conditions**
- `cluster_ready_delay.tf`: 60s after cluster creation
- Gateway API CRDs: 30s establishment wait
- Kgateway CRDs: 30s establishment wait  
- Gateway load balancer: 30s for IP assignment
- Gloo Operator: 30s readiness wait
- Service Mesh Controller: 120s for Istio components
- KubeBlocks CRDs: 30s establishment wait

### **Conditional Architectures**
- **Monitoring**: Basic Prometheus ↔ Prometheus Operator
- **Policy Enforcement**: Optional Kyverno deployment
- **CI/CD**: Optional Argo Workflows
- **Storage**: CSI snapshots for database persistence

### **Cross-namespace Access**
- HTTPRoutes → ReferenceGrants → Gateway access
- Policy Reporter → ServiceMonitor (Prometheus Operator)
- Grafana/Kiali → Gateway API routing

## Key Integration Points

1. **Cilium + Istio**: `cni.exclusive: false` for Ambient Mesh compatibility
2. **Gateway API + TLS**: Cloudflare Origin Certificates
3. **Kyverno + Monitoring**: ServiceMonitor for policy metrics
4. **DNS + Load Balancer**: Cloudflare A records to Gateway IP
5. **Database + Storage**: KubeBlocks with CSI snapshots