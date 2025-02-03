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

resource "cloudflare_zero_trust_access_policy" "allow_github" {
  account_id = local.cloudflare_account_id
  name       = "To SSO with GitHub"
  decision   = "allow"
  include = [{
    group = {
      id = cloudflare_zero_trust_access_group.allow_github.id
    }
  }]
}

resource "cloudflare_zero_trust_access_service_token" "this" {
  name     = "managed token"
  zone_id  = local.cloudflare_zone_id
  duration = "${24 * 365}h" # 1y
}

# Service Token での認証はアクション（`decision`）を`Service Auth`（`non_identity`）にする必要がある
resource "cloudflare_zero_trust_access_policy" "allow_service_token" {
  account_id = local.cloudflare_account_id
  name       = "Allow bypass by service token"
  decision   = "non_identity"
  include = [{
    service_token = {
      token_id = cloudflare_zero_trust_access_service_token.this.id
    }
  }]
}
