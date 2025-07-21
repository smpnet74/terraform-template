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
      # First, identify the correct KubeBlocks resource
      echo "Checking for KubeBlocks resources..."
      kubectl get crds | grep kubeblocks || echo "No KubeBlocks CRDs found"
      
      # Try different possible resource types for KubeBlocks configuration
      if kubectl get KubeBlocks -n kb-system >/dev/null 2>&1; then
        echo "Found KubeBlocks resource, patching..."
        kubectl patch KubeBlocks kubeblocks -n kb-system --type=merge -p '{"spec":{"dataProtection":{"volumeSnapshotClass":"civo-snapshot-class"}}}'
      elif kubectl get kubeblocks.kubeblocks.io -n kb-system >/dev/null 2>&1; then
        echo "Found kubeblocks.kubeblocks.io resource, patching..."
        kubectl patch kubeblocks.kubeblocks.io kubeblocks -n kb-system --type=merge -p '{"spec":{"dataProtection":{"volumeSnapshotClass":"civo-snapshot-class"}}}'
      else
        echo "KubeBlocks resource not found or not ready yet, skipping configuration"
        echo "Available resources in kb-system:"
        kubectl get all -n kb-system || echo "kb-system namespace not found"
      fi
    EOT
  }
  
  # The kubectl patch command above sets the volumeSnapshotClass for KubeBlocks
}
