resource "null_resource" "cilium_upgrade" {
  triggers = {
    cilium_version = "1.17.5"
  }

  depends_on = [
    civo_kubernetes_cluster.cluster
  ]

  provisioner "local-exec" {
    command = <<-EOT
      # Add Cilium Helm repository
      helm repo add cilium https://helm.cilium.io
      helm repo update
      
      # Create values file
      cat > cilium_values.yaml <<EOF
image:
  repository: quay.io/cilium/cilium
  tag: v1.17.5
installCRDs: true
kubeProxyReplacement: true
hubble:
  enabled: true
  relay:
    enabled: true
  ui:
    enabled: true
  flowRetention: 1h
  eventQueueSize: "1048576"
  metrics:
    enabled:
      - dns
      - drop
      - tcp
      - flow
      - icmp
    serviceMonitor:
      enabled: false
metrics:
  enabled: true
EOF
      
      # Upgrade Cilium using Helm
      helm upgrade cilium cilium/cilium \
        --version 1.17.5 \
        --namespace kube-system \
        --reset-values \
        --reuse-values \
        --values cilium_values.yaml \
        --kubeconfig ${path.module}/kubeconfig
    EOT
  }
}
