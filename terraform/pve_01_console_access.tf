# TODO: Fix me

# resource "cloudflare_dns_record" "pxmx01-mng" {
#   zone_id = data.cloudflare_zone.clov3r-cc.id
#   name    = "pxmx01-mng"
#   content = cloudflare_zero_trust_tunnel_cloudflared.cloudflared-01.cname
#   type    = "CNAME"
#   proxied = true
#   ttl     = 1 # Auto
#   comment = "for Cloudflare Tunnel with Proxmox#1"
# }

# resource "cloudflare_zero_trust_access_application" "pxmx01-mng" {
#   zone_id          = data.cloudflare_zone.clov3r-cc.id
#   name             = "Access application for ${cloudflare_dns_record.pxmx01-mng.hostname}"
#   domain           = cloudflare_dns_record.pxmx01-mng.hostname
#   session_duration = "24h"
# }

# resource "cloudflare_zero_trust_access_policy" "pxmx01-mng" {
#   application_id = cloudflare_zero_trust_access_application.pxmx01-mng.id
#   zone_id        = data.cloudflare_zone.clov3r-cc.id
#   name           = "Web Login Policy for ${cloudflare_dns_record.pxmx01-mng.hostname}"
#   precedence     = "1"
#   decision       = "allow"
#   include {
#     group = [cloudflare_zero_trust_access_group.allow_github.id]
#   }
# }

# resource "cloudflare_zero_trust_access_service_token" "managed" {
#   name     = "managed token"
#   zone_id  = data.cloudflare_zone.clov3r-cc.id
#   duration = "8760h" # 1year
# }

# # Service Token での認証はアクション（`decision`）を`Service Auth`（`non_identity`）にする必要がある
# resource "cloudflare_zero_trust_access_policy" "pxmx01-mng__srv-token" {
#   application_id = cloudflare_zero_trust_access_application.pxmx01-mng.id
#   zone_id        = data.cloudflare_zone.clov3r-cc.id
#   name           = "CLI Policy for ${cloudflare_dns_record.pxmx01-mng.hostname}"
#   precedence     = "2"
#   decision       = "non_identity"
#   include {
#     service_token = [cloudflare_zero_trust_access_service_token.managed.id]
#   }
# }
