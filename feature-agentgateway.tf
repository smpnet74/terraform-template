# AgentGateway Feature
# Provides MCP (Model Context Protocol) and A2A (Agent-to-Agent) communication
# Includes management UI accessible at agentgateway.{domain}

module "agentgateway" {
  source = "./feature-agentgateway"
  count  = var.enable_agentgateway ? 1 : 0

  domain_name                = var.domain_name
  enable_prometheus_operator = var.enable_prometheus_operator
  default_gateway_dependency = kubectl_manifest.default_gateway
}

# Output AgentGateway information when enabled
output "agentgateway_info" {
  description = "AgentGateway deployment information"
  value = var.enable_agentgateway ? {
    ui_url       = module.agentgateway[0].ui_url
    mcp_endpoint = module.agentgateway[0].mcp_endpoint
    namespace    = module.agentgateway[0].namespace
  } : null
}