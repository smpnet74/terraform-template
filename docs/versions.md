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

## Service Mesh

| Component | Version | Description |
|-----------|---------|-------------|
| Gloo Operator | Latest | Operator for managing Istio lifecycle |
| Istio | v1.26.2 | Service mesh platform with Ambient Mesh mode |
| Istio CNI | v1.26.2 | CNI plugin for traffic interception (chained with Cilium) |
| Ztunnel | v1.26.2 | Ambient data plane proxy for east-west traffic |

## Machine Learning Platform

| Component | Version | Description |
|-----------|---------|-------------|

| Jupyter Web App | v1.7.0 | Web UI for creating and managing Jupyter notebook servers |
| Notebook Controller | v1.7.0 | Controller for managing notebook instances |
| Volumes Web App | v1.7.0 | Web UI for managing persistent volumes |

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
- Ambient Mesh is installed via Gloo Operator with specific configuration for Cilium compatibility:
  - Istio CNI is configured as a chained plugin alongside Cilium
  - eBPF is used for traffic redirection in ztunnel
  - PILOT_ENABLE_AMBIENT environment variable is set for istiod
  - Installation follows the order: istio-base → istio-cni → istiod → ztunnel
