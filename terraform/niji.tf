resource "cloudflare_dns_record" "auth0_domain" {
  zone_id = local.cloudflare_zone_id
  type    = "CNAME"
  name    = "auth"
  content = "dev-ylboliln6z4iuhd7-cd-jhudqctvydtf51ka.edge.tenants.jp.auth0.com"
  proxied = false
  ttl     = 1 # Auto
  comment = "for Auth0"
}
