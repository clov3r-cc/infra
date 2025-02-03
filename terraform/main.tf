locals {
  # NOTE: zone_id は非シークレット
  # https://github.com/cloudflare/wrangler-legacy/issues/209#issuecomment-541654484
  cloudflare_zone_id    = "b52fd73ec52e35fea1807a173e33e93a"
  cloudflare_account_id = "fff06038a70892193e0fa1e9e270436a"

  domain = "clov3r.cc"
}

data "cloudflare_zone" "clov3r-cc" {
  zone_id = local.cloudflare_zone_id
}
