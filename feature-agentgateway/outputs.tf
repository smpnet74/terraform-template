# AgentGateway Feature Module Outputs

output "namespace" {
  description = "The namespace where AgentGateway is deployed"
  value       = "ai-gateway-system"
}

output "service_name" {
  description = "The name of the AgentGateway service"
  value       = "agentgateway"
}

output "ui_url" {
  description = "The external URL for AgentGateway management UI"
  value       = "https://agentgateway.${var.domain_name}"
}

output "mcp_endpoint" {
  description = "The internal MCP endpoint for agent connections"
  value       = "http://agentgateway.ai-gateway-system.svc.cluster.local:8080"
}

output "deployment_ready" {
  description = "Reference to the deployment for dependency management"
  value       = kubectl_manifest.agentgateway_deployment
}