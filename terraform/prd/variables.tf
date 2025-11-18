#region Cloudflare

variable "cloudflare_api_token" {
  description = "An API token for Cloudflare."
  type        = string
  sensitive   = true
  ephemeral   = true
}

#endregion

#region Proxmox VE

variable "pve_api_token_id" {
  type        = string
  description = "The token ID to access Proxmox VE API."
  sensitive   = true
}

variable "pve_api_token_secret" {
  type        = string
  description = "The UUID/secret of the token defined in the variable `pve_api_token_id`."
  sensitive   = true
}

variable "pve_tls_insecure" {
  type        = bool
  description = "Disable TLS verification while connecting to the Proxmox VE API server."
}

variable "pve_cf_client_id" {
  type        = string
  description = "Service token ID of Cloudflare Zero Trust to access to Proxmox API."
  sensitive   = true
}

variable "pve_cf_client_secret" {
  type        = string
  description = "Service token secret of Cloudflare Zero Trust to access to Proxmox API."
  sensitive   = true
}

variable "pve_user_password" {
  type        = string
  description = "The password for the Proxmox user."
  sensitive   = true
}

variable "vm_ssh_private_key" {
  type        = string
  description = "The private SSH key base64 encoded for the machine user."
  sensitive   = true
}

#endregion

#region Oracle Cloud

variable "oracle_cloud_api_fingerprint" {
  description = "Fingerprint of OCI API private key for Tenancy"
  type        = string
  sensitive   = true
}

variable "oracle_cloud_api_private_key" {
  description = "base64 encoded OCI API private key used for Tenancy"
  type        = string
  sensitive   = true
}

variable "oracle_cloud_user_id" {
  description = "User ID that Terraform will use to create resources for Tenancy"
  type        = string
  sensitive   = true
}

#endregion
