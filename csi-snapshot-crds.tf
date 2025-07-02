# Install CSI Snapshot Controller CRDs
# Required for KubeBlocks dataprotection functionality

resource "null_resource" "csi_snapshot_crds" {
  provisioner "local-exec" {
    command = <<-EOT
      kubectl apply -f https://raw.githubusercontent.com/kubernetes-csi/external-snapshotter/master/client/config/crd/snapshot.storage.k8s.io_volumesnapshotclasses.yaml
      kubectl apply -f https://raw.githubusercontent.com/kubernetes-csi/external-snapshotter/master/client/config/crd/snapshot.storage.k8s.io_volumesnapshotcontents.yaml
      kubectl apply -f https://raw.githubusercontent.com/kubernetes-csi/external-snapshotter/master/client/config/crd/snapshot.storage.k8s.io_volumesnapshots.yaml
    EOT
  }
}

# Wait for CSI Snapshot CRDs to be established
resource "time_sleep" "wait_for_csi_snapshot_crds" {
  depends_on = [null_resource.csi_snapshot_crds]
  create_duration = "10s"
}
