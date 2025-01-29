locals {
  # https://htnosm.hatenablog.com/entry/2021/02/14/090000
  workers_index                   = [for k, v in var.worker_allocated_host : k]
  worker_internal-net_subnet-mask = split("/", var.worker_internal-net_subnet_cidr)[1]
  worker_internal-net_default_gw  = cidrhost(var.worker_internal-net_subnet_cidr, 1)
}

variable "worker_allocated_host" {
  type        = map(string)
  description = "This map shows the name of the Proxmox nodes on which to place the each node."
  default = {
    1 = "lucky-proxmox-01"
  }
}

variable "worker_first_vm_id" {
  type        = number
  description = "The VM id for the first worker node."
}

variable "worker_memory" {
  type        = string
  description = "The amount MB of memory to allocate to the worker node."
}

variable "worker_sockets" {
  type        = number
  description = "The number of CPU sockets to allocate to the worker node."
}

variable "worker_cores" {
  type        = number
  description = "The number of CPU cores per CPU socket to allocate to the worker node."
}

variable "worker_internal-net_bridge" {
  type        = string
  description = "Bridge to which the network device should be attached for internal network."
  default     = "vmbr0"
}

variable "worker_internal-net_subnet_cidr" {
  type        = string
  description = "Subnet CIDR block for internal network."
  default     = "192.168.0.0/24"
}

variable "worker_first_internal-net_host-section" {
  type        = number
  description = "The host section of IP address used by first worker node for internal network."
}

variable "worker_os_disk_size" {
  type        = string
  description = "The disk size for os attached to worker node."
}

resource "random_password" "worker_ci_user_password" {
  count = length(local.workers_index)

  length      = 16
  min_lower   = 3
  min_upper   = 3
  min_numeric = 3
  min_special = 3
}

resource "proxmox_vm_qemu" "worker" {
  for_each = var.worker_allocated_host

  name        = "${var.env_name}-k8s-wk-${format("%02d", index(local.workers_index, each.key) + 1)}"
  target_node = each.value
  vmid        = var.worker_first_vm_id + index(local.workers_index, each.key)
  desc        = "This VM is managed by Terraform to run k8s."
  bios        = "seabios"
  onboot      = true
  agent       = 1
  clone       = var.vm_template
  full_clone  = true
  tags        = "${var.env_name};terraform;k8s;worker"
  qemu_os     = "l26"

  # CPU and memory configuration
  memory  = var.worker_memory
  sockets = var.worker_sockets
  cores   = var.worker_cores
  # vcpus will be calculated by setting sockets and cores automatically
  vcpus = 0
  # "host" will cause kernel panic for RHEL
  cpu_type = "x86-64-v3"
  numa     = true

  hotplug = "network,disk,usb,memory,cpu"
  scsihw  = "virtio-scsi-single"

  # cloud-init configuration
  os_type   = "cloud-init"
  ciuser    = var.vm_user
  ciupgrade = true
  sshkeys   = base64decode(var.vm_ssh_public_key)

  network {
    id     = 0
    model  = "virtio"
    bridge = var.worker_internal-net_bridge
  }

  ipconfig0 = "ip=${cidrhost(var.worker_internal-net_subnet_cidr, var.worker_first_internal-net_host-section + index(local.workers_index, each.key))}${"/${local.worker_internal-net_subnet-mask}"},gw=${local.worker_internal-net_default_gw}"

  disks {
    virtio {
      virtio0 {
        disk {
          size     = var.worker_os_disk_size
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
