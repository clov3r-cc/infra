locals {
  vm_settings__ansible_player = {
    "01" = {
      host_name                = local.pve_hosts["pve-01"]["host_name"]
      vm_id                    = 104
      managemt_nw_host_section = 19
      cpu_socket               = 1
      cpu_core                 = 2
      memory                   = 1024 * 2
      os_disk_size             = 10
    }
  }
}

resource "random_password" "vm_root_password__ansible_player" {
  for_each = local.vm_settings__ansible_player

  length      = 30
  min_lower   = 3
  min_upper   = 3
  min_numeric = 3
  special     = false
}

resource "random_password" "vm_user_password__ansible_player" {
  for_each = local.vm_settings__ansible_player

  length      = 30
  min_lower   = 3
  min_upper   = 3
  min_numeric = 3
  special     = false
}

resource "terraform_data" "cloud_init_config__ansible_player" {
  for_each = local.vm_settings__ansible_player

  connection {
    type        = "ssh"
    host        = local.pve_hosts[each.value.host_name].ip_address
    user        = local.machine_user
    private_key = base64decode(var.vm_ssh_private_key)
  }
  provisioner "file" {
    content = templatefile("cloud-init/${local.env}-ans_cloud-init.yaml.tftpl", {
      CI_HOSTNAME               = "${local.env}-ans-${format("%02d", tonumber(each.key))}",
      CI_ROOT_PASSWORD          = random_password.vm_root_password__ansible_player[each.key].result,
      CI_MACHINEUSER_NAME       = local.machine_user,
      CI_MACHINEUSER_PASSWORD   = random_password.vm_user_password__ansible_player[each.key].result,
      CI_MACHINEUSER_SSH_PUBKEY = base64decode(local.vm_ssh_public_key),
    })
    destination = "/tmp/${local.env}-ans-${format("%02d", tonumber(each.key))}_cloud-init.yaml"
  }
  provisioner "remote-exec" {
    inline = [
      "echo '${var.pve_user_password}' | sudo -S mv /tmp/${local.env}-ans-${format("%02d", tonumber(each.key))}_cloud-init.yaml /var/lib/vz/snippets/",
    ]
  }
}

moved {
  from = null_resource.cloud_init_config__ansible_player
  to   = terraform_data.cloud_init_config__ansible_player
}

resource "proxmox_vm_qemu" "ansible_player" {
  for_each   = local.vm_settings__ansible_player
  depends_on = [terraform_data.cloud_init_config__ansible_player]

  name        = "${local.env}-ans-${format("%02d", tonumber(each.key))}"
  target_node = each.value.host_name
  vmid        = each.value.vm_id
  description = "Run ansible on this server. This VM is managed by Terraform."
  bios        = "seabios"
  onboot      = true
  agent       = 1
  clone       = local.vm_template__alma
  full_clone  = true
  tags        = "${local.env};terraform;ansible;ansible-player"
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
  cicustom = "user=local:snippets/${local.env}-ans-${format("%02d", tonumber(each.key))}_cloud-init.yaml"

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

resource "terraform_data" "ssh_private_key__ansible_player" {
  for_each = { for vm in proxmox_vm_qemu.ansible_player : vm.name => vm }

  connection {
    type        = "ssh"
    host        = each.value.ssh_host
    user        = local.machine_user
    private_key = base64decode(var.vm_ssh_private_key)
  }
  provisioner "remote-exec" {
    inline = [
      "mkdir /home/${local.machine_user}/.ssh || :",
      "chmod 700 /home/${local.machine_user}/.ssh",
    ]
  }
  provisioner "file" {
    content     = base64decode(var.vm_ssh_private_key)
    destination = local.ansible_ssh_private_key_path
  }
  provisioner "remote-exec" {
    inline = [
      "chmod 600 ${local.ansible_ssh_private_key_path}",
    ]
  }
}

resource "ansible_group" "ansible_player" {
  name = "ansible_player"
  variables = {
    ansible_user                 = local.machine_user
    ansible_ssh_private_key_file = local.ansible_ssh_private_key_path
  }
}

resource "ansible_host" "ansible_player" {
  for_each = { for vm in proxmox_vm_qemu.ansible_player : vm.name => vm }

  name   = each.key
  groups = [ansible_group.ansible_player.name]
  variables = {
    ansible_host = each.value.ssh_host
  }
}

resource "terraform_data" "make_ansible_inventory" {
  # TODO: Whenever the number of VM types changes, rewrite this section.
  depends_on = [
    ansible_host.ansible_player, ansible_host.cloud_server, ansible_host.zabbix_server
  ]
  triggers_replace = timestamp()

  provisioner "local-exec" {
    command = <<EOF
    ansible-galaxy collection install cloud.terraform
    ansible-inventory --inventory ${path.root}/ansible/inventory_src.yaml --list --yaml --output ${path.root}/ansible/inventory.yaml
    EOF
  }
}

resource "terraform_data" "send_ansible_files" {
  for_each   = { for vm in proxmox_vm_qemu.ansible_player : vm.name => vm }
  depends_on = [terraform_data.make_ansible_inventory]

  connection {
    type        = "ssh"
    host        = each.value.ssh_host
    user        = local.machine_user
    private_key = base64decode(var.vm_ssh_private_key)
  }
  provisioner "remote-exec" {
    inline = ["mkdir ~/ansible || :"]
  }
  provisioner "file" {
    # NOTE: Trailing slash is intended
    # See: https://developer.hashicorp.com/packer/docs/provisioners/file
    # > If the source, however, is `/foo/` (a trailing slash is present), and the destination is `/tmp`,
    # > then the contents of `/foo` will be uploaded into `/tmp` directly.
    source      = "${path.root}/ansible/"
    destination = "/home/${local.machine_user}/ansible"
  }
}
