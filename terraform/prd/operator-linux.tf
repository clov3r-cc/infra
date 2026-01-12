locals {
  vm_settings__linux_operator = {
    "01" = {
      host_name                 = local.pve_hosts["pve-01"]["host_name"]
      vm_id                     = 104
      managemt_nw_host_section  = 19
      heartbeat_nw_host_section = 3
      cpu_socket                = 1
      cpu_core                  = 2
      memory                    = 1024 * 2
      os_disk_size              = 15
    }
  }
}

resource "random_password" "vm_root_password__linux_operator" {
  for_each = local.vm_settings__linux_operator

  length      = 30
  min_lower   = 3
  min_upper   = 3
  min_numeric = 3
  special     = false
}

resource "random_password" "vm_user_password__linux_operator" {
  for_each = local.vm_settings__linux_operator

  length      = 30
  min_lower   = 3
  min_upper   = 3
  min_numeric = 3
  special     = false
}

resource "terraform_data" "cloud_init_config__linux_operator" {
  for_each = local.vm_settings__linux_operator

  connection {
    type        = "ssh"
    host        = local.pve_hosts[each.value.host_name].ip_address
    user        = local.machine_user
    private_key = base64decode(var.vm_ssh_private_key)
  }
  provisioner "file" {
    content = templatefile("cloud-init/${local.env}-lop_cloud-init.yaml.tftpl", {
      CI_HOSTNAME               = "${local.env}-lop-${format("%02d", tonumber(each.key))}",
      CI_ROOT_PASSWORD          = random_password.vm_root_password__linux_operator[each.key].result,
      CI_MACHINEUSER_NAME       = local.machine_user,
      CI_MACHINEUSER_PASSWORD   = random_password.vm_user_password__linux_operator[each.key].result,
      CI_MACHINEUSER_SSH_PUBKEY = base64decode(local.vm_ssh_public_key),
    })
    destination = "/tmp/${local.env}-lop-${format("%02d", tonumber(each.key))}_cloud-init.yaml"
  }
  provisioner "remote-exec" {
    inline = [
      "echo '${var.pve_user_password}' | sudo -S mv /tmp/${local.env}-lop-${format("%02d", tonumber(each.key))}_cloud-init.yaml /var/lib/vz/snippets/",
    ]
  }
}

resource "proxmox_vm_qemu" "linux_operator" {
  for_each   = local.vm_settings__linux_operator
  depends_on = [terraform_data.cloud_init_config__linux_operator]

  name               = "${local.env}-lop-${format("%02d", tonumber(each.key))}"
  target_node        = each.value.host_name
  vmid               = each.value.vm_id
  description        = "Linux VM to operate something. This VM is managed by Terraform."
  bios               = "seabios"
  start_at_node_boot = true
  agent              = 1
  clone              = local.vm_template__alma
  full_clone         = true
  tags               = "${local.env};terraform;operator;linux-operator"
  qemu_os            = "l26"

  startup_shutdown {
    order            = -1 # Auto
    startup_delay    = -1 # No delay
    shutdown_timeout = -1 # No delay
  }

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
  cicustom = "user=local:snippets/${local.env}-lop-${format("%02d", tonumber(each.key))}_cloud-init.yaml"

  network {
    id     = 0
    model  = "virtio"
    bridge = local.vm_management_nw_bridge
  }

  network {
    id     = 1
    model  = "virtio"
    bridge = local.zabbix_server_heartbeat_nw_bridge
  }

  ipconfig0 = "ip=${cidrhost(local.vm_management_nw_subnet_cidr, each.value.managemt_nw_host_section)}${"/${local.vm_management_nw_subnet_mask}"},gw=${local.vm_management_nw_default_gw}"
  ipconfig1 = "ip=${cidrhost(local.zabbix_server_heartbeat_nw_subnet_cidr, each.value.heartbeat_nw_host_section)}${"/${local.zabbix_server_heartbeat_nw_subnet_mask}"}"

  disks {
    virtio {
      virtio0 {
        disk {
          size     = "${each.value.os_disk_size}G"
          storage  = local.vm_disk_storage
          iothread = true
        }
      }
    }
    ide {
      ide0 {
        cloudinit {
          storage = local.vm_disk_storage
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

resource "ansible_group" "linux_operator" {
  name = "linux_operator"
  variables = {
    ansible_user                 = local.machine_user
    ansible_ssh_private_key_file = local.ansible_ssh_private_key_path
  }
}

resource "ansible_group" "pacemaker_qdevice" {
  name = "pacemaker_qdevice"
}

resource "ansible_host" "linux_operator" {
  for_each = proxmox_vm_qemu.linux_operator

  name   = each.value.name
  groups = [ansible_group.linux_operator.name, ansible_group.pacemaker_qdevice.name]
  variables = {
    ansible_host    = each.value.ssh_host
    heartbeat_nw_ip = split("/", split("ip=", each.value.ipconfig1)[1])[0]
    host_index      = tonumber(each.key)
  }
}
