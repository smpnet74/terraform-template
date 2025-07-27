# AgentGateway Feature Module

This module deploys AgentGateway as a standalone service providing MCP (Model Context Protocol) and A2A (Agent-to-Agent) communication capabilities.

## Overview

AgentGateway is a high-performance Rust-based gateway that provides:
- **MCP Protocol Support**: Model Context Protocol for AI agent communication
- **Management UI**: Web interface for configuration and testing (port 15000)
- **A2A Communication**: Agent-to-agent connectivity
- **Real-time Configuration**: Dynamic backend management without restarts

## Features

- ✅ **Standalone Deployment**: Independent of kgateway version
- ✅ **External UI Access**: Management interface via HTTPRoute
- ✅ **MCP Protocol**: Everything MCP server pre-configured
- ✅ **Prometheus Integration**: ServiceMonitor for metrics collection
- ✅ **RBAC**: Proper service account and cluster role bindings
- ✅ **Health Checks**: Kubernetes liveness and readiness probes

## Usage

```hcl
module "agentgateway" {
  source = "./feature-agentgateway"
  
  domain_name                = var.domain_name
  enable_prometheus_operator = var.enable_prometheus_operator
  default_gateway_dependency = kubectl_manifest.default_gateway
}
```

## Requirements

- **Gateway API**: Requires Gateway API CRDs to be installed
- **Default Gateway**: Needs existing default-gateway resource for HTTPRoute
- **DNS**: Domain must be configured for external access

## Ports

- **8080**: MCP protocol endpoint
- **3000**: HTTP proxy for agent connections  
- **15000**: Management UI (external access)
- **9090**: Prometheus metrics
- **15021**: Health/readiness probes

## Configuration

The module includes a pre-configured MCP backend:
- **Backend Name**: "mcp-everything"
- **Target**: @modelcontextprotocol/server-everything via npx
- **Protocol**: MCP over stdio

## Management UI

Access the management interface at: `https://agentgateway.{domain_name}`

The UI provides:
- Configuration management
- Backend target creation/deletion
- MCP server playground
- Real-time configuration updates

## Environment Variables

Critical environment variables for external UI access:
- `ADMIN_ADDR=0.0.0.0:15000`: Binds admin UI to all interfaces
- `AGENTGATEWAY_ADMIN_ADDR=0.0.0.0:15000`: Fallback binding option

## Outputs

- `namespace`: Deployment namespace (ai-gateway-system)
- `service_name`: Service name (agentgateway)
- `ui_url`: External management UI URL
- `mcp_endpoint`: Internal MCP endpoint for agents
- `deployment_ready`: Deployment reference for dependencies

## Integration

This module integrates with existing infrastructure:
- **Gateway API**: Uses existing default-gateway for routing
- **Prometheus**: Optional ServiceMonitor creation
- **DNS**: Leverages existing domain and certificate setup

## Troubleshooting

See `/docs/agentgatewayhelp.md` for comprehensive troubleshooting guide including:
- Admin interface binding issues
- Port configuration problems
- HTTPRoute routing errors
- Configuration validation failures

## Dependencies

- kubectl provider for Kubernetes resource management
- Existing Gateway API infrastructure
- Default gateway resource for HTTPRoute attachment