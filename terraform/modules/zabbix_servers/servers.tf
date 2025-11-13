locals {
  vm_management_nw_subnet-mask = split("/", var.vm_management_nw_subnet_cidr)[1]
  vm_management_nw_default_gw  = cidrhost(var.vm_management_nw_subnet_cidr, 1)
}

variable "env_name" {
  type        = string
  description = "The environment name."

  validation {
    condition     = contains(["prod", "test"], var.env_name)
    error_message = "Allowed values are 'prod' or 'test'."
  }
}

variable "pve_hosts" {
  type = map(object({
    host_name  = string
    ip_address = string
  }))
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

variable "vm_settings" {
  type = map(object({
    host_name                = string
    vm_id                    = number
    managemt_nw_host-section = string
  }))
}

variable "vm_memory" {
  type        = string
  description = "The amount MB of memory to allocate to the node."
}

variable "vm_cpu_sockets" {
  type        = number
  description = "The number of CPU sockets to allocate to the node."
}

variable "vm_cpu_cores" {
  type        = number
  description = "The number of CPU cores per CPU socket to allocate to the node."
}

variable "vm_management_nw_bridge" {
  type        = string
  description = "Bridge to which the network device should be attached for management network."
  default     = "vmbr0"
}

variable "vm_management_nw_subnet_cidr" {
  type        = string
  description = "Subnet CIDR block for management network."
  default     = "192.168.0.0/24"
}

variable "vm_os_disk_storage" {
  type        = string
  description = "Storage name for the OS disk."
}

variable "vm_os_disk_size" {
  type        = number
  description = "The attached disk size."
}

resource "random_password" "vm_root_password" {
  for_each = var.vm_settings

  length      = 30
  min_lower   = 3
  min_upper   = 3
  min_numeric = 3
  special     = false
}

resource "random_password" "vm_user_password" {
  for_each = var.vm_settings

  length      = 30
  min_lower   = 3
  min_upper   = 3
  min_numeric = 3
  special     = false
}

resource "null_resource" "cloud-init_config" {
  for_each = var.vm_settings

  connection {
    type        = "ssh"
    host        = var.pve_hosts[each.value.host_name].ip_address
    user        = var.pve_user
    private_key = base64decode(var.vm_ssh_private_key)
  }
  provisioner "file" {
    content = templatefile("${path.module}/resources/${var.env_name}-zbx-srv_cloud-init.yaml.tftpl", {
      CI_HOSTNAME               = "${var.env_name}-zbx-srv-${format("%02d", tonumber(each.key))}",
      CI_ROOT_PASSWORD          = random_password.vm_root_password[each.key].result,
      CI_MACHINEUSER_NAME       = var.vm_user,
      CI_MACHINEUSER_PASSWORD   = random_password.vm_user_password[each.key].result,
      CI_MACHINEUSER_SSH_PUBKEY = base64decode(var.vm_ssh_public_key),
    })
    destination = "/tmp/${var.env_name}-zbx-srv-${format("%02d", tonumber(each.key))}_cloud-init.yaml"
  }
  provisioner "remote-exec" {
    inline = [
      "echo '${var.pve_user_password}' | sudo -S mv /tmp/${var.env_name}-zbx-srv-${format("%02d", tonumber(each.key))}_cloud-init.yaml /var/lib/vz/snippets/",
    ]
  }
}

resource "proxmox_vm_qemu" "server" {
  for_each   = var.vm_settings
  depends_on = [null_resource.cloud-init_config]

  name        = "${var.env_name}-zbx-srv-${format("%02d", tonumber(each.key))}"
  target_node = each.value.host_name
  vmid        = each.value.vm_id
  description = "Zabbix Server. This VM is managed by Terraform."
  bios        = "seabios"
  onboot      = true
  agent       = 1
  clone       = var.vm_template
  full_clone  = true
  tags        = "${var.env_name};terraform;zabbix;zabbix-server"
  qemu_os     = "l26"

  cpu {
    sockets = var.vm_cpu_sockets
    cores   = var.vm_cpu_cores
    # vcores will be calculated by setting sockets and cores automatically
    vcores = 0
    type   = "x86-64-v3"
    numa   = true
  }

  memory = var.vm_memory

  hotplug = "network,disk,usb,memory,cpu"
  scsihw  = "virtio-scsi-single"

  # cloud-init configuration
  os_type  = "cloud-init"
  cicustom = "user=local:snippets/${var.env_name}-zbx-srv-${format("%02d", tonumber(each.key))}_cloud-init.yaml"

  network {
    id     = 0
    model  = "virtio"
    bridge = var.vm_management_nw_bridge
  }

  ipconfig0 = "ip=${cidrhost(var.vm_management_nw_subnet_cidr, each.value.managemt_nw_host-section)}${"/${local.vm_management_nw_subnet-mask}"},gw=${local.vm_management_nw_default_gw}"

  disks {
    virtio {
      virtio0 {
        disk {
          size     = "${var.vm_os_disk_size}G"
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
