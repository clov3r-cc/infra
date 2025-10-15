resource "cloudflare_dns_record" "github-pages_domain_verification" {
  zone_id = data.cloudflare_zone.clov3r-cc.id
  type    = "TXT"
  name    = "_gh-clov3r-cc-o"
  content = "3da337285a"
  proxied = false
  ttl     = 1 # Auto
  comment = "for GitHub Pages Domain Verification"
}
