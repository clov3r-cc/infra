terraform {
  required_version = ">= 1.10.0"

  cloud {
    organization = "clov3r-cc"

    workspaces {
      name = "infra-prod"
    }
  }

  required_providers {
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "5.17.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "3.8.1"
    }
    proxmox = {
      source  = "telmate/proxmox"
      version = "3.0.2-rc07"
    }
    oci = {
      source  = "oracle/oci"
      version = "8.0.0"
    }
    ansible = {
      source  = "ansible/ansible"
      version = "1.3.0"
    }
  }
}

provider "cloudflare" {
  api_token = var.cloudflare_api_token
}

provider "random" {
}

provider "proxmox" {
  pm_api_url          = "https://${local.pve_hosts["prod-prox-01"].ip_address}:8006/api2/json"
  pm_api_token_id     = var.pve_api_token_id
  pm_api_token_secret = var.pve_api_token_secret
  pm_http_headers     = "CF-Access-Client-Id,${var.pve_cf_client_id},CF-Access-Client-Secret,${var.pve_cf_client_secret}"
  pm_tls_insecure     = var.pve_tls_insecure
  pm_timeout          = 600
}

provider "oci" {
  tenancy_ocid = local.oracle_cloud_tenancy_id
  user_ocid    = var.oracle_cloud_user_id
  fingerprint  = var.oracle_cloud_api_fingerprint
  private_key  = base64decode(var.oracle_cloud_api_private_key)
  region       = "ap-osaka-1"
}
