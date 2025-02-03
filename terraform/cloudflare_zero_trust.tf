resource "cloudflare_zero_trust_access_group" "allow_github" {
  zone_id = local.cloudflare_zone_id
  name    = "Allow GitHub"
  include = [{
    # GitHub
    login_method = {
      id = "3b628f5e-ce37-44d3-9182-ab59c1331f53"
    }
  }]
}

resource "cloudflare_zero_trust_access_policy" "allow_github" {
  account_id = local.cloudflare_account_id
  name       = "To SSO with GitHub"
  decision   = "allow"
  include = [{
    group = {
      id = cloudflare_zero_trust_access_group.allow_github.id
    }
  }]
}

resource "cloudflare_zero_trust_access_service_token" "this" {
  name     = "managed token"
  zone_id  = local.cloudflare_zone_id
  duration = "${24 * 365}h" # 1y
}

# Service Token での認証はアクション（`decision`）を`Service Auth`（`non_identity`）にする必要がある
resource "cloudflare_zero_trust_access_policy" "allow_service_token" {
  account_id = local.cloudflare_account_id
  name       = "Allow bypass by service token"
  decision   = "non_identity"
  include = [{
    service_token = {
      token_id = cloudflare_zero_trust_access_service_token.this.id
    }
  }]
}
