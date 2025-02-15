locals {
  # https://htnosm.hatenablog.com/entry/2021/02/14/090000
  control_planes_index                   = [for k, v in var.control_plane_allocated_host : k]
  control_plane_internal-net_subnet-mask = split("/", var.control_plane_internal-net_subnet_cidr)[1]
  control_plane_internal-net_default_gw  = cidrhost(var.control_plane_internal-net_subnet_cidr, 1)
}

variable "control_plane_allocated_host" {
  type        = map(string)
  description = "This map shows the name of the Proxmox nodes on which to place the each node."
  default = {
    1 = "lucky-proxmox-01"
  }
}

variable "control_plane_first_vm_id" {
  type        = number
  description = "The VM id for the first control plane node."
}

variable "control_plane_memory" {
  type        = string
  description = "The amount MB of memory to allocate to the control plane node."
}

variable "control_plane_sockets" {
  type        = number
  description = "The number of CPU sockets to allocate to the control plane node."
}

variable "control_plane_cores" {
  type        = number
  description = "The number of CPU cores per CPU socket to allocate to the control plane node."
}

variable "control_plane_internal-net_bridge" {
  type        = string
  description = "Bridge to which the network device should be attached for internal network."
  default     = "vmbr0"
}

variable "control_plane_internal-net_subnet_cidr" {
  type        = string
  description = "Subnet CIDR block for internal network."
  default     = "192.168.0.0/24"
}

variable "control_plane_first_internal-net_host-section" {
  type        = number
  description = "The host section of IP address used by first control plane node for internal network."
}

variable "control_plane_os_disk_size" {
  type        = number
  description = "The disk size for os attached to control plane node."
}

resource "random_password" "vm_root_password__control_plane" {
  for_each = var.control_plane_allocated_host

  length  = 16
  special = true
}

resource "random_password" "vm_user_password__control_plane" {
  for_each = var.control_plane_allocated_host

  length      = 16
  min_lower   = 3
  min_upper   = 3
  min_numeric = 3
  min_special = 3
}

resource "null_resource" "vm_ci_config__control_plane" {
  for_each = var.control_plane_allocated_host

  connection {
    type        = "ssh"
    host        = "192.168.20.2"
    user        = var.pve_user
    private_key = base64decode(var.vm_ssh_private_key)
  }
  provisioner "file" {
    content = templatefile("${path.module}/resources/k8s-vm-cloud-init.yaml.tftpl", {
      CI_ROOT_PASSWORD          = random_password.vm_root_password__control_plane[each.key].result,
      CI_MACHINEUSER_NAME       = var.vm_user,
      CI_MACHINEUSER_PASSWORD   = random_password.vm_user_password__control_plane[each.key].result,
      CI_MACHINEUSER_SSH_PUBKEY = base64decode(var.vm_ssh_public_key),
      CI_RHEL_ACTIVATION_KEY    = var.rhel_activation_key,
      CI_RHEL_ORG               = var.rhel_org,
    })
    destination = "/tmp/${var.env_name}__k8s-vm_ci-config__cp-${format("%02d", index(local.control_planes_index, each.key) + 1)}.yaml"
  }
  provisioner "remote-exec" {
    inline = [
      "echo '${var.pve_user_password}' | sudo -S mv /tmp/${var.env_name}__k8s-vm_ci-config__cp-${format("%02d", index(local.control_planes_index, each.key) + 1)}.yaml /var/lib/vz/snippets/",
    ]
  }
}

resource "proxmox_vm_qemu" "control_plane" {
  for_each   = var.control_plane_allocated_host
  depends_on = [null_resource.vm_ci_config__control_plane]

  name        = "${var.env_name}-k8s-cp-${format("%02d", index(local.control_planes_index, each.key) + 1)}"
  target_node = each.value
  vmid        = var.control_plane_first_vm_id + index(local.control_planes_index, each.key)
  desc        = "This VM is managed by Terraform to run k8s."
  bios        = "seabios"
  onboot      = true
  agent       = 1
  tags        = "${var.env_name};terraform;k8s;control_plane"
  qemu_os     = "l26"

  # CPU and memory configuration
  memory  = var.control_plane_memory
  sockets = var.control_plane_sockets
  cores   = var.control_plane_cores
  # vcpus will be calculated by setting sockets and cores automatically
  vcpus    = 0
  cpu_type = "x86-64-v3"
  numa     = true

  hotplug = "network,disk,usb,memory,cpu"
  scsihw  = "virtio-scsi-single"

  # cloud-init configuration
  os_type  = "cloud-init"
  cicustom = "user=local:snippets/${var.env_name}__k8s-vm_ci-config__cp-${format("%02d", index(local.control_planes_index, each.key) + 1)}.yaml"

  network {
    id     = 0
    model  = "virtio"
    bridge = var.control_plane_internal-net_bridge
  }

  ipconfig0 = "ip=${cidrhost(var.control_plane_internal-net_subnet_cidr, var.control_plane_first_internal-net_host-section + index(local.control_planes_index, each.key))}${"/${local.control_plane_internal-net_subnet-mask}"},gw=${local.control_plane_internal-net_default_gw}"

  disks {
    virtio {
      virtio0 {
        disk {
          size     = "${var.control_plane_os_disk_size}G"
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
