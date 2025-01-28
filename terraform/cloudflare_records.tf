resource "cloudflare_record" "homepage" {
  zone_id = cloudflare_zone.clov3r-cc.id
  type    = "CNAME"
  name    = local.domain
  content = "${cloudflare_pages_project.homepage.name}.pages.dev"
  proxied = true
  ttl     = 1 # Auto
  comment = "for my homepage in Cloudflare Pages"
}

resource "cloudflare_record" "homepage__www" {
  zone_id = cloudflare_zone.clov3r-cc.id
  type    = "CNAME"
  name    = "www"
  content = "${cloudflare_pages_project.homepage.name}.pages.dev"
  proxied = true
  ttl     = 1 # Auto
  comment = "for my homepage in Cloudflare Pages"
}

resource "cloudflare_record" "auth0_domain" {
  zone_id = cloudflare_zone.clov3r-cc.id
  type    = "CNAME"
  name    = "auth"
  content = "dev-ylboliln6z4iuhd7-cd-jhudqctvydtf51ka.edge.tenants.jp.auth0.com"
  proxied = false
  ttl     = 1 # Auto
  comment = "for Auth0"
}

resource "cloudflare_record" "mail-server__primary" {
  zone_id  = cloudflare_zone.clov3r-cc.id
  type     = "MX"
  name     = local.domain
  content  = "cap-l.sakura.ne.jp"
  proxied  = false
  ttl      = 1 # Auto
  priority = 10
  comment  = "for primary mail server in Sakura Internet"
}

resource "cloudflare_record" "mail-server__secondary" {
  zone_id  = cloudflare_zone.clov3r-cc.id
  type     = "MX"
  name     = local.domain
  content  = "www2297.sakura.ne.jp"
  proxied  = false
  ttl      = 1 # Auto
  priority = 20
  comment  = "for secondary mail server in Sakura Internet"
}

resource "cloudflare_record" "mail-server__spf" {
  zone_id = cloudflare_zone.clov3r-cc.id
  type    = "TXT"
  name    = local.domain
  content = "v=spf1 a:www2297.sakura.ne.jp mx ~all"
  proxied = false
  ttl     = 1 # Auto
  comment = "for SPF authentication"
}

resource "cloudflare_record" "mail-server__dmarc" {
  zone_id = cloudflare_zone.clov3r-cc.id
  type    = "TXT"
  name    = "_dmarc"
  content = "v=DMARC1; p=none; aspf=r; adkim=r"
  proxied = false
  ttl     = 1 # Auto
  comment = "for DMARC authentication"
}

resource "cloudflare_record" "mail-server__dkim" {
  zone_id = cloudflare_zone.clov3r-cc.id
  type    = "TXT"
  name    = "rs20240724._domainkey"
  content = "v=DKIM1; k=rsa; p=MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAyQIeA9A4KNo/2kj9fAK+iknZQ2pxP10mvqLc5hO1vTiv/GEDgzGGtxKfoUs2eEfwA1C8L419HivskfJPnEsgbFJ0L3KzINc+Gsfh2K+ntKqB4L/cs23PkNdKKJeJPqDVuME4r3VXXaULxktaa/OTDD1zmOrmh4GsNW73Pu/u9rHr/AA0nerMj3kfgG7YZfb7aZrvKWE1hc4diDEOUYT3ejFsu713+wOmSPTyijRXSHH3BhuajKjoGtSRBlwVOhAcQNDyFzBGV3YuJveRUcbKFew3JiBxMgnyps+rFhfY09uU74WSliSgX2owcvp4DGtSP7YDT3vtgZRaHwxiWgQkYwIDAQAB"
  proxied = false
  ttl     = 1 # Auto
  comment = "for DKIM authentication"
}

resource "cloudflare_record" "github-pages_domain_verification" {
  zone_id = cloudflare_zone.clov3r-cc.id
  type    = "TXT"
  name    = "_gh-clov3r-cc-o"
  content = "3da337285a"
  proxied = false
  ttl     = 1 # Auto
  comment = "for GitHub Pages Domain Verification"
}

resource "cloudflare_record" "pxmx01-mng" {
  zone_id = cloudflare_zone.clov3r-cc.id
  name    = "pxmx01-mng"
  content = cloudflare_zero_trust_tunnel_cloudflared.cloudflared-01.cname
  type    = "CNAME"
  proxied = true
  ttl     = 1 # Auto
  comment = "for Cloudflare Tunnel with Proxmox#1"
}
