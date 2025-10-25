resource "cloudflare_pages_project" "homepage" {
  account_id        = data.cloudflare_account.me.account_id
  name              = "my-home"
  production_branch = "main"
  deployment_configs = {
    preview = {
      always_use_latest_compatibility_date = true
      fail_open                            = true       # Bypass Cloudflare Pages Functions when requests to Functions count towards your quota (default value in GUI)
      usage_model                          = "standard" # In free plan, we can select only standard model (default value in GUI)
    }
    production = {
      always_use_latest_compatibility_date = false # The `always_use_latest_compatibility_date` property cannot be true for Production deployments
      compatibility_date                   = "2025-09-15"
      fail_open                            = true       # Bypass Cloudflare Pages Functions when requests to Functions count towards your quota (default value in GUI)
      usage_model                          = "standard" # In free plan, we can select only standard model (default value in GUI)
    }
  }
}

resource "cloudflare_pages_domain" "clov3r-cc" {
  account_id   = data.cloudflare_account.me.account_id
  project_name = cloudflare_pages_project.homepage.name
  name         = data.cloudflare_zone.clov3r-cc.name
}

resource "cloudflare_pages_domain" "www-clov3r-cc" {
  account_id   = data.cloudflare_account.me.account_id
  project_name = cloudflare_pages_project.homepage.name
  name         = "www.${data.cloudflare_zone.clov3r-cc.name}"
}

resource "cloudflare_dns_record" "homepage" {
  zone_id = data.cloudflare_zone.clov3r-cc.zone_id
  type    = "CNAME"
  name    = data.cloudflare_zone.clov3r-cc.name
  content = "${cloudflare_pages_project.homepage.name}.pages.dev"
  proxied = true
  ttl     = 1 # Auto
  comment = "for my homepage in Cloudflare Pages (This resource is managed with Terraform)"
}

resource "cloudflare_dns_record" "homepage__www" {
  zone_id = data.cloudflare_zone.clov3r-cc.zone_id
  type    = "CNAME"
  name    = "www"
  content = "${cloudflare_pages_project.homepage.name}.pages.dev"
  proxied = true
  ttl     = 1 # Auto
  comment = "for my homepage in Cloudflare Pages (This resource is managed with Terraform)"
}
