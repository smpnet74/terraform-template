# Gloo Operator for Ambient Mesh Installation
# Based on https://ambientmesh.io/docs/setup/gloo-operator/

terraform {
  required_providers {
    kubernetes = {
      source = "hashicorp/kubernetes"
    }
    helm = {
      source = "hashicorp/helm"
    }
    kubectl = {
      source = "gavinbunney/kubectl"
    }
    time = {
      source = "hashicorp/time"
    }
  }
}

# Create namespace for Gloo Operator
resource "kubernetes_namespace" "gloo_operator" {
  metadata {
    name = "gloo-operator"
  }
}

# Install Gloo Operator using Helm
resource "helm_release" "gloo_operator" {
  name       = "gloo-operator"
  repository = ""  # Using OCI registry
  chart      = "oci://us-docker.pkg.dev/solo-public/gloo-operator-helm/gloo-operator"
  namespace  = kubernetes_namespace.gloo_operator.metadata[0].name
  
  # Set atomic to false to prevent rollback on timeout
  atomic = false
  
  # Add timeout to prevent indefinite waiting
  timeout = 900  # 15 minutes
  
  depends_on = [
    kubernetes_namespace.gloo_operator
  ]
}

# Wait for Gloo Operator to be ready
resource "time_sleep" "wait_for_gloo_operator" {
  depends_on = [helm_release.gloo_operator]
  create_duration = "30s"
}

# Create ServiceMeshController resource to install Istio with Ambient Mesh
resource "kubectl_manifest" "service_mesh_controller" {
  yaml_body = templatefile("${path.module}/manifests/service-mesh-controller.yaml", {
    istio_version = var.istio_version
  })

  depends_on = [
    helm_release.gloo_operator,
    time_sleep.wait_for_gloo_operator
  ]
}

# Wait for ServiceMeshController to be ready
resource "time_sleep" "wait_for_service_mesh_controller" {
  depends_on = [kubectl_manifest.service_mesh_controller]
  create_duration = "120s"  # Allow more time for Istio components to be deployed
}