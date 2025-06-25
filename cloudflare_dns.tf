provider "cloudflare" {
  api_token = var.cloudflare_api_token
}

data "kubernetes_service" "traefik_lb" {
  metadata {
    name      = "traefik"
    namespace = "traefik"
  }
  depends_on = [helm_release.traefik_ingress]
}

resource "cloudflare_dns_record" "root" {
  zone_id = var.cloudflare_zone_id
  name    = var.domain_name
  content = data.kubernetes_service.traefik_lb.status.0.load_balancer.0.ingress.0.ip
  type    = "A"
  proxied = false
  ttl     = 1 # Automatic
}

resource "cloudflare_dns_record" "wildcard" {
  zone_id = var.cloudflare_zone_id
  name    = "*"
  content = var.domain_name
  type    = "CNAME"
  proxied = false
  ttl     = 1 # Automatic
}
