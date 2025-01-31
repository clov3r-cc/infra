locals {
  gateway_public-net_default_gw = cidrhost(var.gateway_public-net_subnet_cidr, 1)

  gateway_internal-net_subnet-mask = split("/", var.gateway_internal-net_subnet_cidr)[1]
  gateway_internal-net_default_gw  = cidrhost(var.gateway_internal-net_subnet_cidr, 1)
}

variable "gateway_allocated_host" {
  type        = string
  description = "The name of the Proxmox nodes on which to place this node."
  default     = "lucky-proxmox-01"
}

variable "gateway_vm_id" {
  type        = number
  description = "The VM id for the gateway node."
}

variable "gateway_memory" {
  type        = string
  description = "The amount MB of memory to allocate to the gateway node."
}

variable "gateway_sockets" {
  type        = number
  description = "The number of CPU sockets to allocate to the gateway node."
}

variable "gateway_cores" {
  type        = number
  description = "The number of CPU cores per CPU socket to allocate to the gateway node."
}

variable "gateway_public-net_bridge" {
  type        = string
  description = "Bridge to which the network device should be attached for public network."
  default     = "vmbr0"
}

variable "gateway_public-net_subnet_cidr" {
  type        = string
  description = "Subnet CIDR block for public network."
  default     = "192.168.0.0/24"
}

variable "gateway_internal-net_bridge" {
  type        = string
  description = "Bridge to which the network device should be attached for internal network."
  default     = "vmbr0"
}

variable "gateway_internal-net_subnet_cidr" {
  type        = string
  description = "Subnet CIDR block for internal network."
  default     = "192.168.0.0/24"
}

variable "gateway_internal-net_host-section" {
  type        = number
  description = "The host section of IP address used by first gateway node for internal network."
}

variable "gateway_os_disk_size" {
  type        = number
  description = "The disk size for os attached to gateway node."
}

resource "proxmox_vm_qemu" "gateway" {
  name        = "${var.env_name}-k8s-gw-01"
  target_node = var.gateway_allocated_host
  vmid        = var.gateway_vm_id
  desc        = "This VM is managed by Terraform to run k8s."
  bios        = "seabios"
  onboot      = true
  agent       = 1
  clone       = var.vm_template
  full_clone  = true
  tags        = "${var.env_name};terraform;k8s;gateway"
  qemu_os     = "l26"

  # CPU and memory configuration
  memory  = var.gateway_memory
  sockets = var.gateway_sockets
  cores   = var.gateway_cores
  # vcpus will be calculated by setting sockets and cores automatically
  vcpus    = 0
  cpu_type = "x86-64-v3"
  numa     = true

  hotplug = "network,disk,usb,memory,cpu"
  scsihw  = "virtio-scsi-single"

  # cloud-init configuration
  os_type    = "cloud-init"
  ciuser     = var.vm_user
  cipassword = var.vm_user_password
  ciupgrade  = true
  sshkeys    = base64decode(var.vm_ssh_public_key)

  network {
    id     = 0
    model  = "virtio"
    bridge = var.gateway_public-net_bridge
  }

  network {
    id     = 1
    model  = "virtio"
    bridge = var.gateway_internal-net_bridge
  }

  ipconfig0 = "ip=${var.gateway_public-net_subnet_cidr},gw=${local.gateway_public-net_default_gw}"
  ipconfig1 = "ip=${cidrhost(var.gateway_internal-net_subnet_cidr, var.gateway_internal-net_host-section)}${"/${local.gateway_internal-net_subnet-mask}"},gw=${local.gateway_internal-net_default_gw}"

  disks {
    virtio {
      virtio0 {
        disk {
          size     = "${var.gateway_os_disk_size}G"
          storage  = var.vm_os_disk_storage
          iothread = true
        }
      }
    }
    ide {
      ide0 {
        cloudinit {
          storage = var.vm_os_disk_storage
        }
      }
    }
  }

  serial {
    id   = 0
    type = "socket"
  }

  vga {
    type = "serial0"
  }

  lifecycle {
    ignore_changes = [
      tags
    ]
  }
}

# TODO: add ssh secret key
