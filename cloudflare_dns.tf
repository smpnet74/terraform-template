provider "cloudflare" {
  api_token = var.cloudflare_api_token
}

# Get the Gateway load balancer IP
data "kubernetes_service" "gateway_lb" {
  metadata {
    name      = "default-gateway"
    namespace = "default"
  }
  depends_on = [
    kubectl_manifest.default_gateway,
    time_sleep.wait_for_gateway_lb # Wait for the load balancer to be fully provisioned
  ]
}

# Use a local value to safely handle the IP address with a fallback
locals {
  # Check if the gateway service has a load balancer IP assigned
  gateway_lb_ip = try(
    data.kubernetes_service.gateway_lb.status[0].load_balancer[0].ingress[0].ip,
    try(data.kubernetes_service.gateway_lb.status[0].load_balancer[0].ingress[0].hostname, "")
  )
  
  # Validate that we have a valid IP address
  has_valid_ip = length(local.gateway_lb_ip) > 0 && local.gateway_lb_ip != "192.0.2.1"
}

# Add a delay to ensure the Gateway service is fully ready and has an assigned IP
resource "time_sleep" "wait_for_gateway_lb" {
  depends_on = [kubectl_manifest.default_gateway]
  create_duration = "120s" # Increased wait time to ensure IP assignment
}

resource "cloudflare_dns_record" "root" {
  zone_id = var.cloudflare_zone_id
  name    = var.domain_name
  content = local.gateway_lb_ip
  type    = "A"
  proxied = false
  ttl     = 1 # Automatic
  depends_on = [time_sleep.wait_for_gateway_lb]
  
  lifecycle {
    precondition {
      condition     = local.has_valid_ip
      error_message = "Gateway load balancer IP address is not available yet. Please run terraform apply again after the load balancer IP is assigned."
    }
  }
}

resource "cloudflare_dns_record" "wildcard" {
  zone_id = var.cloudflare_zone_id
  name    = "*"
  content = local.gateway_lb_ip  # Point directly to Gateway IP
  type    = "A"                 # Change to A record
  proxied = false
  ttl     = 1 # Automatic
  depends_on = [time_sleep.wait_for_gateway_lb]
  
  lifecycle {
    precondition {
      condition     = local.has_valid_ip
      error_message = "Gateway load balancer IP address is not available yet. Please run terraform apply again after the load balancer IP is assigned."
    }
  }
}
