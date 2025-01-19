resource "random_password" "tunnel_secret" {
  length = 64
}

resource "cloudflare_zero_trust_tunnel_cloudflared" "cloudflared-01" {
  account_id = local.cloudflare_account_id
  name       = "Terraform tunnel to proxmox-01 container in lucky-proxmox-01"
  secret     = base64sha256(random_password.tunnel_secret.result)
}

resource "cloudflare_zero_trust_tunnel_cloudflared_config" "cloudflared-01" {
  tunnel_id  = cloudflare_zero_trust_tunnel_cloudflared.cloudflared-01.id
  account_id = local.cloudflare_account_id
  config {
    ingress_rule {
      hostname = cloudflare_record.pxmx01-mng.hostname
      service  = "https://192.168.20.2:8006"
      origin_request {
        no_tls_verify = true
      }
    }
    ingress_rule {
      service = "http_status:404"
    }
  }
}

resource "cloudflare_zero_trust_access_application" "pxmx01-mng" {
  zone_id = cloudflare_zone.clov3r-cc.id
  name    = "Access application for pxmx01-mng.${cloudflare_zone.clov3r-cc.zone}"
  domain  = "pxmx01-mng.${cloudflare_zone.clov3r-cc.zone}"
  destinations = [{
    type = "public"
    uri  = "ssh-pxmx01-mng.${cloudflare_zone.clov3r-cc.zone}"
  }]
  session_duration = "24h"
}

resource "cloudflare_zero_trust_access_group" "allow_github" {
  account_id = local.cloudflare_account_id
  name       = "Allow GitHub"
  include {
    # GitHub
    login_method = ["3b628f5e-ce37-44d3-9182-ab59c1331f53"]
  }
}

resource "cloudflare_zero_trust_access_service_token" "managed" {
  name     = "managed token"
  zone_id  = cloudflare_zone.clov3r-cc.id
  duration = "8760h" # 1year
}

resource "cloudflare_zero_trust_access_policy" "pxmx01-mng" {
  application_id = cloudflare_zero_trust_access_application.pxmx01-mng.id
  zone_id        = cloudflare_zone.clov3r-cc.id
  name           = "Web Login Policy for pxmx01-mng.${cloudflare_zone.clov3r-cc.zone}"
  precedence     = "1"
  decision       = "allow"
  include {
    group = [cloudflare_zero_trust_access_group.allow_github.id]
  }
}

# Service Token での認証はアクション（`decision`）を`Service Auth`（`non_identity`）にする必要がある
resource "cloudflare_zero_trust_access_policy" "pxmx01-mng__srv-token" {
  application_id = cloudflare_zero_trust_access_application.pxmx01-mng.id
  zone_id        = cloudflare_zone.clov3r-cc.id
  name           = "CLI Policy for pxmx01-mng.${cloudflare_zone.clov3r-cc.zone}"
  precedence     = "2"
  decision       = "non_identity"
  include {
    service_token = [cloudflare_zero_trust_access_service_token.managed.id]
  }
}
