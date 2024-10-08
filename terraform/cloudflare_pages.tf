resource "cloudflare_pages_project" "homepage" {
  account_id        = local.cloudflare_account_id
  name              = "my-home"
  production_branch = "main"
  deployment_configs {
    preview {
      always_use_latest_compatibility_date = true
      fail_open                            = true       # Bypass Cloudflare Pages Functions when requests to Functions count towards your quota (default value in GUI)
      usage_model                          = "standard" # In free plan, we can select only standard model (default value in GUI)
    }
    production {
      always_use_latest_compatibility_date = false # The `always_use_latest_compatibility_date` property cannot be true for Production deployments
      compatibility_date                   = "2024-06-03"
      fail_open                            = true       # Bypass Cloudflare Pages Functions when requests to Functions count towards your quota (default value in GUI)
      usage_model                          = "standard" # In free plan, we can select only standard model (default value in GUI)
    }
  }
}

resource "cloudflare_pages_domain" "clov3r-cc" {
  account_id   = local.cloudflare_account_id
  project_name = cloudflare_pages_project.homepage.name
  domain       = local.domain
}

resource "cloudflare_pages_domain" "www-clov3r-cc" {
  account_id   = local.cloudflare_account_id
  project_name = cloudflare_pages_project.homepage.name
  domain       = "www.${local.domain}"
}
