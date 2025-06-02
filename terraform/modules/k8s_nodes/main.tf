terraform {
  required_providers {
    proxmox = {
      source  = "telmate/proxmox"
      version = "3.0.1-rc9"
    }
    random = {
      source  = "hashicorp/random"
      version = "3.7.2"
    }
  }
}

variable "env_name" {
  type        = string
  description = "The environment name."

  validation {
    condition     = contains(["prod", "test"], var.env_name)
    error_message = "Allowed values are 'prod' or 'test'."
  }
}

variable "pve_user" {
  type        = string
  description = "The user name for the Proxmox user."
}

variable "pve_user_password" {
  type        = string
  description = "The password for the Proxmox user."
  sensitive   = true
}

variable "vm_user" {
  type        = string
  description = "User name to access each VM with SSH."
}

variable "vm_ssh_public_key" {
  type        = string
  description = "The public key to ssh each VM."
}

variable "vm_ssh_private_key" {
  type        = string
  description = "The private SSH key base64 encoded for the machine user."
  sensitive   = true
}

variable "vm_template" {
  type        = string
  description = "Template name for VMs."
}

variable "vm_os_disk_storage" {
  type        = string
  description = "Storage name for the OS disk."
}

variable "rhel_activation_key" {
  type        = string
  description = "The activation key for RHEL subscription."
  sensitive   = true
}

variable "rhel_org" {
  type        = string
  description = "The organization ID for RHEL subscription."
  sensitive   = true
}
