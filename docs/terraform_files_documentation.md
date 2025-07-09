# Terraform Files Documentation

This document provides an overview of the Terraform files in this project and explains their purpose.

## Core Infrastructure

### `cluster.tf`
Creates and configures the Civo Kubernetes cluster with Cilium CNI. Also generates a local kubeconfig file for accessing the cluster.

### `provider.tf`
Configures the Terraform providers used in the project, including Kubernetes, Helm, and kubectl providers.

### `io.tf`
Defines input variables and output values for the Terraform project. Contains variable declarations that control the behavior of the infrastructure deployment.

### `outputs.tf`
Defines the output values that are displayed after Terraform applies the configuration, such as cluster information and endpoints.

## Networking and DNS

### `cloudflare_dns.tf`
Configures Cloudflare DNS records to point to the Kubernetes Gateway load balancer IP address. Sets up both root domain and wildcard DNS entries.

### `civo_firewall-cluster.tf`
Configures the Civo firewall rules for the Kubernetes cluster to control inbound and outbound traffic.

### `civo_firewall-ingress.tf`
Sets up firewall rules specifically for ingress traffic to the cluster.

### `kgateway_api.tf`
Installs and configures the Gateway API and Kgateway implementation for ingress traffic management. Creates a default Gateway resource for HTTP and HTTPS traffic.

### `kgateway_certificate.tf`
Manages TLS certificates for the Gateway, including Cloudflare Origin Certificates.

## GitOps Configuration

### `github.tf`
Creates and configures the GitHub repository used for ArgoCD GitOps deployments.

### `argocd_applications.tf`
Defines the root ArgoCD application that manages all other applications in the cluster using the GitOps approach.

### `argocd_bookinfo.tf`
Configures the Bookinfo module which sets up the Bookinfo sample application through ArgoCD.

### `argocd_kubeflow.tf`
Configures the Kubeflow module which deploys Kubeflow through ArgoCD.

## Helm Deployments

### `helm_argocd.tf`
Installs and configures ArgoCD using Helm, setting up the GitOps controller for the cluster.

### `helm_cilium.tf`
Configures Cilium network policies and CNI features using Helm.

### `helm_gloo_operator.tf`
Installs and configures the Gloo Mesh operator using Helm.

### `helm_grafana.tf`
Deploys Grafana for monitoring and visualization using Helm.

### `helm_kiali.tf`
Deploys Kiali dashboard for service mesh visualization using Helm.

### `helm_kubeblocks.tf`
Installs KubeBlocks for database management on Kubernetes using Helm.

## HTTP Routes

### `httproute_argocd.tf`
Configures the HTTPRoute for ArgoCD server, making it accessible through the Gateway.

### `httproute_grafana.tf`
Configures the HTTPRoute for Grafana, making it accessible through the Gateway.

### `httproute_kiali.tf`
Configures the HTTPRoute for Kiali dashboard, making it accessible through the Gateway.

## Storage and Snapshots

### `civo-volumesnapshotclass.tf`
Configures the VolumeSnapshotClass resource for Civo storage.

### `csi-snapshot-crds.tf`
Installs the Container Storage Interface (CSI) snapshot Custom Resource Definitions (CRDs).

## Dependency Management

### `cluster_ready_delay.tf`
Implements delays to ensure the cluster is fully ready before deploying resources.

### `kubectl_dependencies.tf`
Manages dependencies between Kubernetes resources to ensure proper deployment order.

## Modules

The project includes two main modules (not detailed as per request):

- `modules/bookinfo/`: Manages the Bookinfo sample application deployment
- `modules/kubeflow/`: Manages the Kubeflow machine learning platform deployment
