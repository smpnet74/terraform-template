# Gloo Operator for Ambient Mesh Installation
# Based on https://ambientmesh.io/docs/setup/gloo-operator/

# Create namespace for Gloo Operator
resource "kubernetes_namespace" "gloo_operator" {
  metadata {
    name = "gloo-operator"
  }

  depends_on = [
    civo_kubernetes_cluster.cluster,
    time_sleep.wait_for_cluster
  ]
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
    kubernetes_namespace.gloo_operator,
    null_resource.cilium_upgrade  # Ensure Cilium is fully deployed first with cni.exclusive: false
  ]
}

# Wait for Gloo Operator to be ready
resource "time_sleep" "wait_for_gloo_operator" {
  depends_on = [helm_release.gloo_operator]
  create_duration = "30s"
}

# Create ServiceMeshController resource to install Istio with Ambient Mesh
resource "kubectl_manifest" "service_mesh_controller" {
  yaml_body = <<-EOF
    apiVersion: operator.gloo.solo.io/v1
    kind: ServiceMeshController
    metadata:
      name: managed-istio
      labels:
        app.kubernetes.io/name: managed-istio
    spec:
      dataplaneMode: Ambient
      installNamespace: istio-system
      version: 1.26.2
      # Additional configuration for Cilium compatibility
      values:
        pilot:
          env:
            PILOT_ENABLE_AMBIENT: "true"
        global:
          platform: k3s
        cni:
          enabled: true
          chained: true
          ambient: true
          cniBinDir: "/opt/cni/bin"
          cniConfDir: "/etc/cni/net.d"
          profile: ambient
        ambient:
          redirectMode: ebpf
        meshConfig:
          defaultConfig:
            interceptionMode: NONE
        # Telemetry addons
        prometheus:
          enabled: true
          service:
            annotations: {}
        kiali:
          enabled: true
          dashboard:
            auth:
              strategy: anonymous
          prometheusAddr: http://prometheus.istio-system:9090
  EOF

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


