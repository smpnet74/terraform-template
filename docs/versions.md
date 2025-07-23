# Platform Component Versions

This document provides a comprehensive and accurate list of all components and their versions deployed in the Kubernetes platform. All versions are managed declaratively through Terraform variables in `io.tf`.

## Core Infrastructure

| Component | Version | Description |
|---|---|---|
| Kubernetes (K3s) | `1.30.5-k3s1` | The core Kubernetes distribution provided by Civo. |

## Networking Stack

| Component | Version | Description |
|---|---|---|
| Cilium CNI | `1.17.5` | The Container Network Interface for networking, observability, and security. |
| Hubble | `1.17.5` | The observability component of Cilium. |
| Gateway API | `v1.2.1` | The Kubernetes standard for modern ingress and traffic management. |
| Kgateway | `v2.0.3` | The specific implementation of the Gateway API used in this platform. |

## Service Mesh (Istio)

| Component | Version | Description |
|---|---|---|
| Istio | `1.26.2` | The service mesh providing zero-trust security and traffic management. |
| Gloo Operator | Managed | The operator responsible for managing the Istio lifecycle. Version is tied to the module. |

## Security & Governance

| Component | Version | Description |
|---|---|---|
| Kyverno | `1.14.4` | The policy engine for Kubernetes. Deployed via Helm chart `v3.4.4`. |
| Kyverno Policies | Chart `v3.4.4` | A set of pre-built security policies for pod security standards. |
| Policy Reporter | Chart `v2.22.0` | A web-based UI for observing and managing Kyverno policy reports. |

## CI/CD & Workflows

| Component | Version | Description |
|---|---|---|
| Argo Workflows | `3.6.10` | A container-native workflow engine. Deployed via Helm chart `v0.45.19`. |
| Argo Events | `1.9.6` | The event-driven automation component for Argo. Deployed via Helm chart `v2.4.15`. |
| EventBus (JetStream) | `2.10.10` | The NATS JetStream event bus used by Argo Events. |
| Metrics Server | Chart `v3.12.1` | Collects resource metrics from nodes and pods. |

## Observability

| Component | Version | Description |
|---|---|---|
| Kube Prometheus Stack | Chart `v61.9.0` | A comprehensive monitoring stack including Prometheus, Alertmanager, and Grafana. |
| Grafana | Managed | Metrics visualization dashboard. Version is managed by the Prometheus stack chart. |
| Kiali | Managed | Service mesh observability dashboard. Version is managed by its operator. |

## MLOps & Data Platform

| Component | Version | Description |
|---|---|---|
| ZenML | `0.84.0` | An extensible MLOps framework for building production-ready ML pipelines. |
| KubeBlocks | `1.0.0` | A database management operator for creating and managing stateful workloads. |
| ZenML PostgreSQL | `15.3.0` | The specific version of PostgreSQL used by ZenML, deployed via KubeBlocks. |

## Terraform Providers

This section details the versions of the Terraform providers used to build and manage the platform.

| Provider | Version | Description |
|---|---|---|
| `civo/civo` | `1.0.35` | Manages Civo cloud resources like the cluster and firewall. |
| `hashicorp/helm` | `2.13.1` | Deploys and manages Helm charts. |
| `hashicorp/kubernetes` | `2.31.0` | Interacts with the Kubernetes API to manage resources. |
| `gavinbunney/kubectl` | `~> 1.14` | Applies raw Kubernetes manifests, bypassing some provider caching issues. |
| `cloudflare/cloudflare` | `5.5.0` | Manages DNS records in Cloudflare. |
| `integrations/github` | `~> 6.0` | Manages the GitHub repository for GitOps. |
| `hashicorp/local` | `2.5.1` | Manages local files, used for saving the kubeconfig. |
| `hashicorp/time` | `~> 0.10.0` | Provides time-based resources for creating delays. |
| `hashicorp/random` | `~> 3.6.0` | Generates random values, used for passwords or unique names. |
