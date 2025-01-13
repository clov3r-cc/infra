locals {
  # NOTE: account_id は非シークレット
  # https://github.com/cloudflare/wrangler-legacy/issues/209#issuecomment-541654484
  cloudflare_account_id = "fff06038a70892193e0fa1e9e270436a"
  domain                = "clov3r.cc"
}

resource "cloudflare_zone" "clov3r-cc" {
  account_id = local.cloudflare_account_id
  zone       = local.domain
}
