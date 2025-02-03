# 2025/2/3: provder cloudflare/cloudflare can't include `login_method` in access group
data "cloudflare_zero_trust_access_group" "allow_github" {
  account_id = local.cloudflare_account_id
  group_id   = "82e31d68-40a9-458c-a3f8-da668c6f2db7"
}

resource "cloudflare_zero_trust_access_policy" "allow_github" {
  account_id = local.cloudflare_account_id
  name       = "To SSO with GitHub"
  decision   = "allow"
  include = [{
    group = {
      id = data.cloudflare_zero_trust_access_group.allow_github.group_id
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
