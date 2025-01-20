variable "cloudflare_api_token" {
  description = "An API token for Cloudflare."
  type        = string
  sensitive   = true
}

variable "pm_host_ssh_port" {
  type        = number
  description = "Port to ssh proxmox host"
  sensitive   = true
}
