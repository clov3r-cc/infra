resource "cloudflare_dns_record" "pxmx01-mng" {
  zone_id = local.cloudflare_zone_id
  name    = "pxmx01-mng"
  content = "${cloudflare_zero_trust_tunnel_cloudflared.cloudflared-01.id}.cfargotunnel.com"
  type    = "CNAME"
  proxied = true
  ttl     = 1 # Auto
  comment = "for Cloudflare Tunnel with Proxmox#1"
}

resource "cloudflare_zero_trust_access_application" "pxmx01-mng" {
  zone_id          = local.cloudflare_zone_id
  type             = "self_hosted"
  name             = "Access application for ${cloudflare_dns_record.pxmx01-mng.name}"
  domain           = cloudflare_dns_record.pxmx01-mng.name
  session_duration = "24h"
  policies = [{
    id         = cloudflare_zero_trust_access_policy.allow_github.id
    precedence = "1"
    }, {
    id         = cloudflare_zero_trust_access_policy.allow_service_token.id
    precedence = "2"
  }]
}
