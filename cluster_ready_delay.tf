# Add a delay after cluster creation to ensure the API server is fully ready
resource "time_sleep" "wait_for_cluster" {
  depends_on = [
    civo_kubernetes_cluster.cluster,
    local_file.cluster-config
  ]
  
  # Wait for 60 seconds after cluster creation
  create_duration = "60s"
}
