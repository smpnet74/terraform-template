# Gloo Operator for Istio Ambient Mesh Integration

module "gloo_operator" {
  source = "./operator-gloo"
  
  istio_version = var.istio_version
  
  depends_on = [
    civo_kubernetes_cluster.cluster,
    time_sleep.wait_for_cluster,
    null_resource.cilium_upgrade  # Ensure Cilium is fully deployed first with cni.exclusive: false
  ]
}