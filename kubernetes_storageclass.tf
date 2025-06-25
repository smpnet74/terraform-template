resource "kubernetes_storage_class_v1" "longhorn" {
  metadata {
    name = "longhorn"
    annotations = {
      "storageclass.kubernetes.io/is-default-class" = "true"
    }
  }
  storage_provisioner = "driver.longhorn.io"
  reclaim_policy      = "Delete"
  parameters = {
    "numberOfReplicas"       = "3"
    "staleReplicaTimeout"    = "2880" # 48 hours in minutes
    "fromBackup"             = ""
    "fsType"                 = "ext4"
  }

  depends_on = [helm_release.longhorn]
}
