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
      version = "5.12.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "3.7.2"
    }
    proxmox = {
      source  = "telmate/proxmox"
      version = "3.0.2-rc05"
    }
    null = {
      source  = "hashicorp/null"
      version = "3.2.4"
    }
    oci = {
      source  = "oracle/oci"
      version = "7.26.1"
    }
  }
}

provider "cloudflare" {
  api_token = var.cloudflare_api_token
}

provider "random" {
}

provider "proxmox" {
  pm_api_url          = "https://${local.pve_hosts["pve-01"].ip_address}:8006/api2/json"
  pm_api_token_id     = var.pve_api_token_id
  pm_api_token_secret = var.pve_api_token_secret
  pm_http_headers     = "CF-Access-Client-Id,${var.pve_cf_client_id},CF-Access-Client-Secret,${var.pve_cf_client_secret}"
  pm_tls_insecure     = var.pve_tls_insecure
  pm_timeout          = 600
}

provider "oci" {
  tenancy_ocid = var.oracle_cloud_tenancy_id
  user_ocid    = var.oracle_cloud_user_id
  fingerprint  = var.oracle_cloud_api_fingerprint
  private_key  = base64decode(var.oracle_cloud_api_private_key)
  region       = "ap-osaka-1"
}

# TODO: Remove this
data "oci_identity_availability_domains" "ad" {
  #Required
  compartment_id = var.oracle_cloud_tenancy_id
}
