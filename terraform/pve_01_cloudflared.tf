# TODO: Fix me

# resource "random_password" "tunnel_secret" {
#   length = 64
# }

# resource "cloudflare_zero_trust_tunnel_cloudflared" "cloudflared-01" {
#   account_id = local.cloudflare_account_id
#   name       = "Terraform tunnel to proxmox-01 container in lucky-proxmox-01"
#   secret     = base64sha256(random_password.tunnel_secret.result)
# }

# resource "cloudflare_zero_trust_tunnel_cloudflared_config" "cloudflared-01" {
#   tunnel_id  = cloudflare_zero_trust_tunnel_cloudflared.cloudflared-01.id
#   account_id = local.cloudflare_account_id
#   config {
#     ingress_rule {
#       hostname = cloudflare_record.pxmx01-mng.hostname
#       service  = "https://192.168.20.2:8006"
#       origin_request {
#         no_tls_verify = true
#       }
#     }
#     ingress_rule {
#       service = "http_status:404"
#     }
#   }
# }
