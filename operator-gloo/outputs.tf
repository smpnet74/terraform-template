# Gloo Operator Outputs

output "gloo_operator_namespace" {
  description = "Namespace where Gloo Operator is installed"
  value       = kubernetes_namespace.gloo_operator.metadata[0].name
}

output "service_mesh_controller" {
  description = "ServiceMeshController resource reference"
  value       = kubectl_manifest.service_mesh_controller
}

output "ambient_mesh_status_command" {
  value = "kubectl describe servicemeshcontroller managed-istio"
  description = "Command to check the status of the Ambient Mesh installation"
}

output "ambient_mesh_pods_command" {
  value = "kubectl get pods -n istio-system"
  description = "Command to check the status of the Istio pods"
}