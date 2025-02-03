resource "cloudflare_dns_record" "mail-server__primary" {
  zone_id  = local.cloudflare_zone_id
  type     = "MX"
  name     = local.domain
  content  = "cap-l.sakura.ne.jp"
  proxied  = false
  ttl      = 1 # Auto
  priority = 10
  comment  = "for primary mail server in Sakura Internet"
}

resource "cloudflare_dns_record" "mail-server__secondary" {
  zone_id  = local.cloudflare_zone_id
  type     = "MX"
  name     = local.domain
  content  = "www2297.sakura.ne.jp"
  proxied  = false
  ttl      = 1 # Auto
  priority = 20
  comment  = "for secondary mail server in Sakura Internet"
}

resource "cloudflare_dns_record" "mail-server__spf" {
  zone_id = local.cloudflare_zone_id
  type    = "TXT"
  name    = local.domain
  content = "v=spf1 a:www2297.sakura.ne.jp mx ~all"
  proxied = false
  ttl     = 1 # Auto
  comment = "for SPF authentication"
}

resource "cloudflare_dns_record" "mail-server__dmarc" {
  zone_id = local.cloudflare_zone_id
  type    = "TXT"
  name    = "_dmarc"
  content = "v=DMARC1; p=none; aspf=r; adkim=r"
  proxied = false
  ttl     = 1 # Auto
  comment = "for DMARC authentication"
}

resource "cloudflare_dns_record" "mail-server__dkim" {
  zone_id = local.cloudflare_zone_id
  type    = "TXT"
  name    = "rs20240724._domainkey"
  content = "v=DKIM1; k=rsa; p=MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAyQIeA9A4KNo/2kj9fAK+iknZQ2pxP10mvqLc5hO1vTiv/GEDgzGGtxKfoUs2eEfwA1C8L419HivskfJPnEsgbFJ0L3KzINc+Gsfh2K+ntKqB4L/cs23PkNdKKJeJPqDVuME4r3VXXaULxktaa/OTDD1zmOrmh4GsNW73Pu/u9rHr/AA0nerMj3kfgG7YZfb7aZrvKWE1hc4diDEOUYT3ejFsu713+wOmSPTyijRXSHH3BhuajKjoGtSRBlwVOhAcQNDyFzBGV3YuJveRUcbKFew3JiBxMgnyps+rFhfY09uU74WSliSgX2owcvp4DGtSP7YDT3vtgZRaHwxiWgQkYwIDAQAB"
  proxied = false
  ttl     = 1 # Auto
  comment = "for DKIM authentication"
}
