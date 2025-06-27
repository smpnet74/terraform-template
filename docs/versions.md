# Component Versions

This document provides a comprehensive list of all components and their versions deployed in the Kubernetes cluster.

## Core Infrastructure

| Component | Version | Description |
|-----------|---------|-------------|
| Kubernetes | v1.28.7+k3s1 | Base Kubernetes cluster running on Civo Cloud |
| Terraform | N/A | Infrastructure as Code tool used to manage all resources |

## Networking Stack

| Component | Version | Description |
|-----------|---------|-------------|
| Cilium CNI | v1.17.5 | Container Network Interface providing networking and network policy |
| Hubble | v1.17.5 | Observability layer for Cilium providing network flow visibility |
| Gateway API | v1.2.1 | Kubernetes Gateway API CRDs for modern ingress management |
| Kgateway | v2.0.2 | Gateway API implementation for ingress traffic |

## Security & Certificate Management

| Component | Version | Description |
|-----------|---------|-------------|
| cert-manager | v1.15.1 | Certificate management controller for Kubernetes |
| Let's Encrypt | N/A | Certificate Authority used for TLS certificates |
| Cloudflare DNS | N/A | DNS provider used for DNS01 challenge validation |

## GitOps & Continuous Delivery

| Component | Version | Description |
|-----------|---------|-------------|
| ArgoCD | v7.3.8 | Declarative GitOps continuous delivery tool for Kubernetes |

## Architecture Roadmap Components

The following components are part of the architecture evolution roadmap but not yet implemented:

| Component | Status | Description |
|-----------|--------|-------------|
| Dapr | Planned | Application building-blocks for cloud-native applications |
| AI Gateway | Planned | Specialized Gateway API implementation for LLM traffic |
| Ambient Mesh | Planned | Service mesh for east-west mTLS, retries, and telemetry |

## Notes

- All components are deployed and managed via Terraform
- Cilium is configured with Hubble for observability
- Kgateway is configured with wildcard TLS certificate for all subdomains
- ArgoCD is configured for GitOps-based application deployment
