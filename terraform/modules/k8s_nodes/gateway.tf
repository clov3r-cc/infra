locals {
  gateway_public-net_default_gw = cidrhost(var.gateway_public-net_subnet_cidr, 1)

  gateway_internal-net_subnet-mask = split("/", var.gateway_internal-net_subnet_cidr)[1]
  gateway_internal-net_default_gw  = cidrhost(var.gateway_internal-net_subnet_cidr, 1)

  ci_config_filename__gateway = "k8s-vm_ci-config__gateway.yaml"
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

resource "random_password" "vm_root_password__gateway" {
  length      = 16
  min_lower   = 3
  min_upper   = 3
  min_numeric = 3
  special     = false
}

resource "random_password" "vm_user_password__gateway" {
  length      = 16
  min_lower   = 3
  min_upper   = 3
  min_numeric = 3
  special     = false
}

resource "null_resource" "vm_ci_config__gateway" {
  connection {
    type        = "ssh"
    host        = "192.168.20.2"
    user        = var.pve_user
    private_key = base64decode(var.vm_ssh_private_key)
  }
  provisioner "file" {
    content = templatefile("${path.module}/resources/k8s-vm-cloud-init.yaml.tftpl", {
      CI_HOSTNAME               = "${var.env_name}-k8s-gw-01",
      CI_ROOT_PASSWORD          = random_password.vm_root_password__gateway.result,
      CI_MACHINEUSER_NAME       = var.vm_user,
      CI_MACHINEUSER_PASSWORD   = random_password.vm_user_password__gateway.result,
      CI_MACHINEUSER_SSH_PUBKEY = base64decode(var.vm_ssh_public_key),
      CI_RHEL_ACTIVATION_KEY    = var.rhel_activation_key,
      CI_RHEL_ORG               = var.rhel_org,
    })
    destination = "/tmp/${var.env_name}__${local.ci_config_filename__gateway}"
  }
  provisioner "remote-exec" {
    inline = [
      "echo '${var.pve_user_password}' | sudo -S mv /tmp/${var.env_name}__${local.ci_config_filename__gateway} /var/lib/vz/snippets/",
    ]
  }
}

resource "proxmox_vm_qemu" "gateway" {
  depends_on = [null_resource.vm_ci_config__gateway]

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
  os_type  = "cloud-init"
  cicustom = "user=local:snippets/${var.env_name}__${local.ci_config_filename__gateway}"

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

resource "null_resource" "gateway_provision_ssh_private_key__pve" {
  connection {
    type        = "ssh"
    host        = "192.168.20.2"
    user        = var.pve_user
    private_key = base64decode(var.vm_ssh_private_key)
  }
  provisioner "remote-exec" {
    inline = [
      "mkdir /home/${var.vm_user}/.ssh",
      "chmod 700 /home/${var.vm_user}/.ssh",
    ]
  }
  provisioner "file" {
    content     = base64decode(var.vm_ssh_private_key)
    destination = "/home/${var.vm_user}/.ssh/id_ed25519"
  }
  provisioner "remote-exec" {
    inline = [
      "chmod 600 /home/${var.vm_user}/.ssh/id_ed25519",
    ]
  }
}

resource "null_resource" "gateway_provision_ssh_private_key__gateway" {
  connection {
    type        = "ssh"
    host        = proxmox_vm_qemu.gateway.ssh_host
    user        = var.vm_user
    private_key = base64decode(var.vm_ssh_private_key)
  }
  provisioner "remote-exec" {
    inline = [
      "mkdir /home/${var.vm_user}/.ssh",
      "chmod 700 /home/${var.vm_user}/.ssh",
    ]
  }
  provisioner "file" {
    content     = base64decode(var.vm_ssh_private_key)
    destination = "/home/${var.vm_user}/.ssh/id_ed25519"
  }
  provisioner "remote-exec" {
    inline = [
      "chmod 600 /home/${var.vm_user}/.ssh/id_ed25519",
    ]
  }
}

resource "null_resource" "gateway_provision_ip_routing" {
  connection {
    type        = "ssh"
    host        = proxmox_vm_qemu.gateway.ssh_host
    user        = var.vm_user
    private_key = base64decode(var.vm_ssh_private_key)
  }
  provisioner "file" {
    source      = "${path.module}/resources/ip-routing.sh"
    destination = "/tmp/ip-routing.sh"
  }
  provisioner "remote-exec" {
    inline = [
      "chmod +x /tmp/ip-routing.sh",
      "echo '${random_password.vm_user_password__gateway.result}' | sudo -S /tmp/ip-routing.sh",
    ]
  }
}
