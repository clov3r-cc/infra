locals {
  # https://htnosm.hatenablog.com/entry/2021/02/14/090000
  server_index                     = [for k, v in var.server_allocated_host : k]
  server_management_nw_subnet-mask = split("/", var.server_management_nw_subnet_cidr)[1]
  server_management_nw_default_gw  = cidrhost(var.server_management_nw_subnet_cidr, 1)
}

variable "server_allocated_host" {
  type        = map(string)
  description = "This map shows the name of the Proxmox nodes on which to place the each node."
  default = {
    1 = "proxmox-01"
    2 = "proxmox-01"
  }
}

variable "server_first_vm_id" {
  type        = number
  description = "The VM id for the first worker node."
}

variable "server_memory" {
  type        = string
  description = "The amount MB of memory to allocate to the worker node."
}

variable "server_sockets" {
  type        = number
  description = "The number of CPU sockets to allocate to the worker node."
}

variable "server_cores" {
  type        = number
  description = "The number of CPU cores per CPU socket to allocate to the worker node."
}

variable "server_management_nw_bridge" {
  type        = string
  description = "Bridge to which the network device should be attached for internal network."
  default     = "vmbr0"
}

variable "server_management_nw_subnet_cidr" {
  type        = string
  description = "Subnet CIDR block for internal network."
  default     = "192.168.0.0/24"
}

variable "server_first_management_nw_host-section" {
  type        = number
  description = "The host section of IP address used by first node for internal network."
}

variable "server_os_disk_size" {
  type        = number
  description = "The attached disk size."
}

resource "random_password" "vm_root_password" {
  for_each = var.server_allocated_host

  length      = 30
  min_lower   = 3
  min_upper   = 3
  min_numeric = 3
  special     = false
}

resource "random_password" "vm_user_password" {
  for_each = var.server_allocated_host

  length      = 30
  min_lower   = 3
  min_upper   = 3
  min_numeric = 3
  special     = false
}

resource "null_resource" "cloud-init_config" {
  for_each = var.server_allocated_host

  connection {
    type        = "ssh"
    host        = "192.168.120.2"
    user        = var.pve_user
    private_key = base64decode(var.vm_ssh_private_key)
  }
  provisioner "file" {
    content = templatefile("${path.module}/resources/${var.env_name}-zbx-srv_cloud-init.yaml.tftpl", {
      CI_HOSTNAME               = "${var.env_name}-zbx-srv-${format("%02d", index(local.server_index, each.key) + 1)}",
      CI_ROOT_PASSWORD          = random_password.vm_root_password[each.key].result,
      CI_MACHINEUSER_NAME       = var.vm_user,
      CI_MACHINEUSER_PASSWORD   = random_password.vm_user_password[each.key].result,
      CI_MACHINEUSER_SSH_PUBKEY = base64decode(var.vm_ssh_public_key),
    })
    destination = "/tmp/${var.env_name}-zbx-srv-${format("%02d", index(local.server_index, each.key) + 1)}_cloud-init.yaml"
  }
  provisioner "remote-exec" {
    inline = [
      "echo '${var.pve_user_password}' | sudo -S mv /tmp/${var.env_name}-zbx-srv-${format("%02d", index(local.server_index, each.key) + 1)}_cloud-init.yaml /var/lib/vz/snippets/",
    ]
  }
}

resource "proxmox_vm_qemu" "server" {
  for_each   = var.server_allocated_host
  depends_on = [null_resource.cloud-init_config]

  name        = "${var.env_name}-zbx-srv-${format("%02d", index(local.server_index, each.key) + 1)}"
  target_node = each.value
  vmid        = var.server_first_vm_id + index(local.server_index, each.key)
  desc        = "This VM is managed by Terraform."
  bios        = "seabios"
  onboot      = true
  agent       = 1
  clone       = var.vm_template
  full_clone  = true
  tags        = "${var.env_name};terraform;zabbix;zabbix-server"
  qemu_os     = "l26"

  cpu {
    sockets = var.server_sockets
    cores   = var.server_cores
    # vcores will be calculated by setting sockets and cores automatically
    vcores = 0
    type   = "x86-64-v3"
    numa   = true
  }

  memory = var.server_memory

  hotplug = "network,disk,usb,memory,cpu"
  scsihw  = "virtio-scsi-single"

  # cloud-init configuration
  os_type  = "cloud-init"
  cicustom = "user=local:snippets/${var.env_name}-zbx-srv-${format("%02d", index(local.server_index, each.key) + 1)}_cloud-init.yaml"

  network {
    id     = 0
    model  = "virtio"
    bridge = var.server_management_nw_bridge
  }

  ipconfig0 = "ip=${cidrhost(var.server_management_nw_subnet_cidr, var.server_first_management_nw_host-section + index(local.server_index, each.key))}${"/${local.server_management_nw_subnet-mask}"},gw=${local.server_management_nw_default_gw}"

  disks {
    virtio {
      virtio0 {
        disk {
          size     = "${var.server_os_disk_size}G"
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
