# Create a VolumeSnapshotClass for Civo CSI driver
# This enables KubeBlocks to use volume snapshots for database backups

# Wait for the Kubernetes API to be available
resource "time_sleep" "wait_for_kubernetes" {
  depends_on = [civo_kubernetes_cluster.cluster, local_file.cluster-config]
  create_duration = "60s"
}

# Create VolumeSnapshotClass using kubectl instead of kubernetes_manifest
resource "null_resource" "civo_volumesnapshotclass" {
  depends_on = [time_sleep.wait_for_kubernetes, null_resource.csi_snapshot_crds]
  
  provisioner "local-exec" {
    environment = {
      KUBECONFIG = "${path.module}/kubeconfig"
    }
    command = <<-EOT
      cat <<EOF | kubectl apply -f -
      apiVersion: snapshot.storage.k8s.io/v1
      kind: VolumeSnapshotClass
      metadata:
        name: civo-snapshot-class
        annotations:
          snapshot.storage.kubernetes.io/is-default-class: "true"
      driver: csi.civo.com
      deletionPolicy: Delete
      EOF
    EOT
  }
}

# Configure the VolumeSnapshotClass for KubeBlocks
resource "null_resource" "configure_kubeblocks_snapshot" {
  depends_on = [null_resource.civo_volumesnapshotclass, time_sleep.wait_for_kubernetes]
  
  provisioner "local-exec" {
    environment = {
      KUBECONFIG = "${path.module}/kubeconfig"
    }
    command = <<-EOT
      kubectl patch kubeblocks kubeblocks -n kb-system --type=merge -p '{"spec":{"dataProtection":{"volumeSnapshotClass":"civo-snapshot-class"}}}' || true
    EOT
  }
  
  # The kubectl patch command above sets the volumeSnapshotClass for KubeBlocks
}
