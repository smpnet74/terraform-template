# KubeBlocks Database Management Platform Integration

module "kubeblocks" {
  source = "./operator-kubeblocks"
  
  kubeblocks_version = var.kubeblocks_version
  kubeconfig_path    = "${path.module}/kubeconfig"
  
  depends_on = [
    local_file.cluster-config
  ]
}