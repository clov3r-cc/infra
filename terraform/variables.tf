variable "cloudflare_api_token" {
  description = "An API token for Cloudflare."
  type        = string
  sensitive   = true
}

variable "pve_host_ssh_port" {
  type        = string
  description = "Port to ssh proxmox host"
  sensitive   = true
}

