# KubeBlocks Operator Outputs

output "kubeblocks_namespace" {
  description = "Namespace where KubeBlocks is installed"
  value       = kubernetes_namespace.kb_system.metadata[0].name
}

output "kubeblocks_version" {
  description = "Version of KubeBlocks installed"
  value       = helm_release.kubeblocks.version
}

output "kubeblocks_info" {
  description = "Information about the KubeBlocks installation and available addons"
  value = join("\n", [
    "KubeBlocks has been installed in the kb-system namespace.",
    "",
    "kubectl apply -f operator-kubeblocks/manifests/test-postgres.yaml",
    "kubectl apply -f operator-kubeblocks/manifests/test-postgres-ha.yaml", 
    "kubectl apply -f operator-kubeblocks/manifests/test-redis.yaml",
    "kubectl apply -f operator-kubeblocks/manifests/test-mongodb.yaml"
  ])
}