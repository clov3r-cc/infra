variable "cloudflare_api_token" {
  description = "An API token for Cloudflare."
  type        = string
  sensitive   = true
  ephemeral   = true
}

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

variable "vm_user" {
  type        = string
  description = "The default user for all VMs"
  default     = "ubuntu"
}

variable "vm_ssh_public_key" {
  type        = string
  description = "SSH public keys in base64"
}
