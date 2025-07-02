# Create a VolumeSnapshotClass for Civo CSI driver
# This enables KubeBlocks to use volume snapshots for database backups

resource "kubernetes_manifest" "civo_volumesnapshotclass" {
  manifest = {
    apiVersion = "snapshot.storage.k8s.io/v1"
    kind       = "VolumeSnapshotClass"
    metadata = {
      name = "civo-snapshot-class"
      annotations = {
        "snapshot.storage.kubernetes.io/is-default-class" = "true"
      }
    }
    driver = "csi.civo.com"
    deletionPolicy = "Delete"
  }
}

# Configure the VolumeSnapshotClass for KubeBlocks
resource "null_resource" "configure_kubeblocks_snapshot" {
  depends_on = [kubernetes_manifest.civo_volumesnapshotclass]
  
  provisioner "local-exec" {
    command = <<-EOT
      kubectl patch kubeblocks kubeblocks -n kb-system --type=merge -p '{"spec":{"dataProtection":{"volumeSnapshotClass":"civo-snapshot-class"}}}' || true
    EOT
  }
  
  # The kubectl patch command above sets the volumeSnapshotClass for KubeBlocks
}
