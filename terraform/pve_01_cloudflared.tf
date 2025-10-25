resource "cloudflare_zero_trust_tunnel_cloudflared" "cloudflared-01" {
  account_id = data.cloudflare_account.me.account_id
  name       = "Terraform tunnel for proxmox-01 container in proxmox-01 (This resource is managed with Terraform)"
}

resource "cloudflare_zero_trust_tunnel_cloudflared_config" "cloudflared-01" {
  tunnel_id  = cloudflare_zero_trust_tunnel_cloudflared.cloudflared-01.id
  account_id = data.cloudflare_account.me.account_id
  config = {
    ingress = [
      {
        hostname = "${cloudflare_dns_record.pxmx01-mng.name}.${data.cloudflare_zone.clov3r-cc.name}"
        service  = "https://192.168.20.2:8006"
        origin_request = {
          no_tls_verify = true
        }
      },
      {
        service = "http_status:404"
      }
    ]
  }
}

resource "cloudflare_dns_record" "pxmx01-mng" {
  zone_id = data.cloudflare_zone.clov3r-cc.zone_id
  name    = "pxmx01-mng"
  content = cloudflare_zero_trust_tunnel_cloudflared.cloudflared-01.id
  type    = "CNAME"
  proxied = true
  ttl     = 1 # Auto
  comment = "for Cloudflare Tunnel with Proxmox#1 (This resource is managed with Terraform)"
}

resource "cloudflare_zero_trust_access_application" "pxmx01-mng" {
  zone_id          = data.cloudflare_zone.clov3r-cc.zone_id
  name             = "Access application for ${cloudflare_dns_record.pxmx01-mng.name}.${data.cloudflare_zone.clov3r-cc.name} (This resource is managed with Terraform)"
  domain           = "${cloudflare_dns_record.pxmx01-mng.name}.${data.cloudflare_zone.clov3r-cc.name}"
  session_duration = "24h"
}

resource "cloudflare_zero_trust_access_policy" "pxmx01-mng" {
  application_id = cloudflare_zero_trust_access_application.pxmx01-mng.id
  zone_id        = data.cloudflare_zone.clov3r-cc.zone_id
  name           = "Web Login Policy for ${cloudflare_dns_record.pxmx01-mng.name}.${data.cloudflare_zone.clov3r-cc.name}"
  precedence     = "1"
  decision       = "allow"
  include {
    group = [cloudflare_zero_trust_access_group.allow_github.id]
  }
}

resource "cloudflare_zero_trust_access_service_token" "managed" {
  name     = "managed token"
  zone_id  = data.cloudflare_zone.clov3r-cc.zone_id
  duration = "8760h" # 1year
}

# Service Token での認証はアクション（`decision`）を`Service Auth`（`non_identity`）にする必要がある
resource "cloudflare_zero_trust_access_policy" "pxmx01-mng__srv-token" {
  application_id = cloudflare_zero_trust_access_application.pxmx01-mng.id
  zone_id        = data.cloudflare_zone.clov3r-cc.zone_id
  name           = "CLI Policy for ${cloudflare_dns_record.pxmx01-mng.name}.${data.cloudflare_zone.clov3r-cc.name}"
  precedence     = "2"
  decision       = "non_identity"
  include {
    service_token = [cloudflare_zero_trust_access_service_token.managed.id]
  }
}
