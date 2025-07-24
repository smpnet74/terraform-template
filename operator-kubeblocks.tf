# KubeBlocks Database Management Platform Integration

module "kubeblocks" {
  source = "./operator-kubeblocks"
  
  kubeblocks_version = var.kubeblocks_version
  enable_neo4j_addon = var.enable_neo4j_addon
  kubeconfig_path    = "${path.module}/kubeconfig"
  
  depends_on = [
    local_file.cluster-config
  ]
}