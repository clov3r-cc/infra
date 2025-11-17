locals {
  vm_settings__zabbix_server = {
    "01" = {
      host_name                = local.pve_hosts["pve-01"]["host_name"]
      vm_id                    = 102
      managemt_nw_host_section = 14
      cpu_socket               = 1
      cpu_core                 = 2
      memory                   = 1024 * 3
      os_disk_size             = 15
    }
    "02" = {
      host_name                = local.pve_hosts["pve-01"]["host_name"]
      vm_id                    = 103
      managemt_nw_host_section = 15
      cpu_socket               = 1
      cpu_core                 = 2
      memory                   = 1024 * 3
      os_disk_size             = 15
    }
  }
}

resource "random_password" "vm_root_password__zabbix_server" {
  for_each = local.vm_settings__zabbix_server

  length      = 30
  min_lower   = 3
  min_upper   = 3
  min_numeric = 3
  special     = false
}

resource "random_password" "vm_user_password__zabbix_server" {
  for_each = local.vm_settings__zabbix_server

  length      = 30
  min_lower   = 3
  min_upper   = 3
  min_numeric = 3
  special     = false
}

resource "null_resource" "cloud_init_config__zabbix_server" {
  for_each = local.vm_settings__zabbix_server

  connection {
    type        = "ssh"
    host        = local.pve_hosts[each.value.host_name].ip_address
    user        = local.machine_user
    private_key = base64decode(var.vm_ssh_private_key)
  }
  provisioner "file" {
    content = templatefile("resources/${local.env}-zbx_cloud-init.yaml.tftpl", {
      CI_HOSTNAME               = "${local.env}-zbx-${format("%02d", tonumber(each.key))}",
      CI_ROOT_PASSWORD          = random_password.vm_root_password__zabbix_server[each.key].result,
      CI_MACHINEUSER_NAME       = local.machine_user,
      CI_MACHINEUSER_PASSWORD   = random_password.vm_user_password__zabbix_server[each.key].result,
      CI_MACHINEUSER_SSH_PUBKEY = base64decode(local.vm_ssh_public_key),
    })
    destination = "/tmp/${local.env}-zbx-${format("%02d", tonumber(each.key))}_cloud-init.yaml"
  }
  provisioner "remote-exec" {
    inline = [
      "echo '${var.pve_user_password}' | sudo -S mv /tmp/${local.env}-zbx-${format("%02d", tonumber(each.key))}_cloud-init.yaml /var/lib/vz/snippets/",
    ]
  }
}

resource "proxmox_vm_qemu" "zabbix_server" {
  for_each   = local.vm_settings__zabbix_server
  depends_on = [null_resource.cloud_init_config__zabbix_server]

  name        = "${local.env}-zbx-${format("%02d", tonumber(each.key))}"
  target_node = each.value.host_name
  vmid        = each.value.vm_id
  description = "Zabbix Server. This VM is managed by Terraform."
  bios        = "seabios"
  onboot      = true
  agent       = 1
  clone       = local.vm_template__alma
  full_clone  = true
  tags        = "${local.env};terraform;zabbix;zabbix-server"
  qemu_os     = "l26"

  cpu {
    sockets = each.value.cpu_socket
    cores   = each.value.cpu_core
    # vcores will be calculated by setting sockets and cores automatically
    vcores = 0
    type   = "x86-64-v3"
    numa   = true
  }

  memory = each.value.memory

  hotplug = "network,disk,usb,memory,cpu"
  scsihw  = "virtio-scsi-single"

  # cloud-init configuration
  os_type  = "cloud-init"
  cicustom = "user=local:snippets/${local.env}-zbx-${format("%02d", tonumber(each.key))}_cloud-init.yaml"

  network {
    id     = 0
    model  = "virtio"
    bridge = local.vm_management_nw_bridge
  }

  ipconfig0 = "ip=${cidrhost(local.vm_management_nw_subnet_cidr, each.value.managemt_nw_host_section)}${"/${local.vm_management_nw_subnet_mask}"},gw=${local.vm_management_nw_default_gw}"

  disks {
    virtio {
      virtio0 {
        disk {
          size     = "${each.value.os_disk_size}G"
          storage  = local.vm_os_disk_storage
          iothread = true
        }
      }
    }
    ide {
      ide0 {
        cloudinit {
          storage = local.vm_os_disk_storage
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
