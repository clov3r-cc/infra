resource "cloudflare_zero_trust_access_group" "allow_github" {
  account_id = local.cloudflare_account_id
  name       = "Allow GitHub"
  include = [{
    login_method = {
      # GitHub
      id = "3b628f5e-ce37-44d3-9182-ab59c1331f53"
    }
  }]
}
