provider "cloudflare" {
  api_token = var.cloudflare_api_token
}

# Get the Gateway load balancer IP
data "kubernetes_service" "gateway_lb" {
  metadata {
    name      = "default-gateway"
    namespace = "default"
  }
  depends_on = [kubectl_manifest.default_gateway]
}

# Use a local value to safely handle the IP address with a fallback
locals {
  # Check if the gateway service has a load balancer IP assigned
  gateway_lb_ip = try(
    data.kubernetes_service.gateway_lb.status[0].load_balancer[0].ingress[0].ip,
    "192.0.2.1" # Fallback to a placeholder IP (TEST-NET-1 from RFC 5737)
  )
}

# Add a delay to ensure the Gateway service is fully ready
resource "time_sleep" "wait_for_gateway_lb" {
  depends_on = [kubectl_manifest.default_gateway]
  create_duration = "30s"
}

resource "cloudflare_dns_record" "root" {
  zone_id = var.cloudflare_zone_id
  name    = var.domain_name
  content = local.gateway_lb_ip
  type    = "A"
  proxied = false
  ttl     = 1 # Automatic
  depends_on = [time_sleep.wait_for_gateway_lb]
}

resource "cloudflare_dns_record" "wildcard" {
  zone_id = var.cloudflare_zone_id
  name    = "*"
  content = local.gateway_lb_ip  # Point directly to Gateway IP
  type    = "A"                 # Change to A record
  proxied = false
  ttl     = 1 # Automatic
  depends_on = [time_sleep.wait_for_gateway_lb]
}
