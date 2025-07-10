# Component Versions

This document provides a comprehensive list of all components and their versions deployed in the Kubernetes cluster.

## Core Infrastructure

| Component | Version | Description |
|-----------|---------|-------------|
| Kubernetes | 1.30.5-k3s1 | Base Kubernetes cluster running on Civo Cloud |
| Terraform | N/A | Infrastructure as Code tool used to manage all resources |

## Networking Stack

| Component | Version | Description |
|-----------|---------|-------------|
| Cilium CNI | v1.17.5 | Container Network Interface providing networking and network policy |
| Hubble | v1.17.5 | Observability layer for Cilium providing network flow visibility |
| Gateway API | v1.2.1 | Kubernetes Gateway API CRDs for modern ingress management |
| Kgateway | v2.0.3 | Gateway API implementation for ingress traffic |

## Security & Certificate Management

| Component | Version | Description |
|-----------|---------|-------------|
| Cloudflare Origin Certificates | N/A | TLS certificates provided by Cloudflare for secure connections |
| Cloudflare DNS | N/A | DNS provider with proxying enabled for additional security |
| Cloudflare SSL/TLS | Full | Encryption mode used between Cloudflare and origin server |

## GitOps & Continuous Delivery

| Component | Version | Description |
|-----------|---------|-------------|
| ArgoCD | v7.3.8 | Declarative GitOps continuous delivery tool for Kubernetes |

## Continuous Integration & Workflows

| Component | Version | Description |
|-----------|---------|-------------|
| Argo Workflows | v3.6.10 (Chart: v0.45.19) | Container-native workflow engine for CI/CD |
| Argo Events | v1.9.6 (Chart: v2.4.15) | Event-driven workflow automation |
| EventBus (JetStream) | v2.9.6 | Event streaming for Argo Events communication |

## Service Mesh

| Component | Version | Description |
|-----------|---------|-------------|
| Gloo Operator | Latest | Operator for managing Istio lifecycle |
| Istio | v1.26.2 | Service mesh platform with Ambient Mesh mode |
| Istio CNI | v1.26.2 | CNI plugin for traffic interception (chained with Cilium) |
| Ztunnel | v1.26.2 | Ambient data plane proxy for east-west traffic |

## Observability Stack

| Component | Version | Description |
|-----------|---------|-------------|
| Grafana | Latest | Metrics visualization and dashboards |
| Prometheus | Latest | Metrics collection and monitoring |
| Kiali | Latest | Service mesh observability and management |

## Database Platform

| Component | Version | Description |
|-----------|---------|-------------|
| KubeBlocks | v1.0.0 | Cloud-native database management platform |
| PostgreSQL Addon | Latest | PostgreSQL database engine support |
| Redis Addon | Latest | Redis in-memory database support |
| MongoDB Addon | Latest | MongoDB document database support |

## Architecture Roadmap Components

The following components are part of the architecture evolution roadmap but not yet implemented:

| Component | Status | Description |
|-----------|--------|-------------|
| Dapr | Planned | Application building-blocks for cloud-native applications |
| AI Gateway | Planned | Specialized Gateway API implementation for LLM traffic |

## Notes

- All components are deployed and managed via Terraform
- Cilium is configured with Hubble for observability and `cni.exclusive: false` for Ambient Mesh compatibility
- Kgateway is configured with wildcard TLS certificate for all subdomains
- ArgoCD is configured for GitOps-based application deployment
- Argo Workflows provides in-cluster CI/CD with Kaniko for container builds
- Ambient Mesh is installed via Gloo Operator with specific configuration for Cilium compatibility:
  - Istio CNI is configured as a chained plugin alongside Cilium
  - eBPF is used for traffic redirection in ztunnel
  - PILOT_ENABLE_AMBIENT environment variable is set for istiod
  - Installation follows the order: istio-base → istio-cni → istiod → ztunnel
- All components are accessible via HTTPRoutes through the default Gateway
- Version pinning is configurable via Terraform variables for Argo Workflows components
