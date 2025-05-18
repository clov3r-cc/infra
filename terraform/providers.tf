terraform {
  required_version = ">= 1.10.0"

  cloud {
    organization = "clov3r-cc"

    workspaces {
      name = "infra"
    }
  }

  required_providers {
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "4.51.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "3.6.3"
    }
    proxmox = {
      source  = "telmate/proxmox"
      version = "3.0.1-rc9"
    }
    null = {
      source  = "hashicorp/null"
      version = "3.2.4"
    }
  }
}

provider "cloudflare" {
  api_token = var.cloudflare_api_token
}

provider "random" {
}

provider "proxmox" {
  pm_api_url          = "https://${local.pve_hosts["pve-01"]["console_domain"]}/api2/json"
  pm_api_token_id     = var.pve_api_token_id
  pm_api_token_secret = var.pve_api_token_secret
  pm_http_headers     = "CF-Access-Client-Id,${var.pve_cf_client_id},CF-Access-Client-Secret,${var.pve_cf_client_secret}"
  pm_tls_insecure     = var.pve_tls_insecure
  pm_timeout          = 600
}
