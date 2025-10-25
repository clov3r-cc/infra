resource "cloudflare_zero_trust_access_group" "allow_github" {
  account_id = data.cloudflare_account.me.account_id
  name       = "Allow GitHub"
  include = [{
    # GitHub
    login_method = {
      id = "3b628f5e-ce37-44d3-9182-ab59c1331f53"
    }
  }]
}
