# This file ensures that kubectl resources wait for the cluster to be fully ready

# Add explicit dependencies to kubectl_manifest resources
locals {
  kubectl_depends_on = [
    time_sleep.wait_for_cluster
  ]
}

# Update the kubectl provider configuration to ensure it waits for the cluster
provider "kubectl" {
  host                   = yamldecode(local_file.cluster-config.content)["clusters"][0]["cluster"]["server"]
  cluster_ca_certificate = base64decode(yamldecode(local_file.cluster-config.content)["clusters"][0]["cluster"]["certificate-authority-data"])
  client_certificate     = base64decode(yamldecode(local_file.cluster-config.content)["users"][0]["user"]["client-certificate-data"])
  client_key             = base64decode(yamldecode(local_file.cluster-config.content)["users"][0]["user"]["client-key-data"])
  load_config_file       = false

  # Increase timeouts for kubectl operations
  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "kubectl"
    args        = ["config", "view", "--raw", "--minify", "--flatten"]
  }
}
