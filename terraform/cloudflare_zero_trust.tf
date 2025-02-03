resource "cloudflare_zero_trust_access_group" "allow_github" {
  zone_id = local.cloudflare_zone_id
  name    = "Allow GitHub"
  include = [{
    # GitHub
    login_method = ["3b628f5e-ce37-44d3-9182-ab59c1331f53"]
  }]
}
