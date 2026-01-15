locals {
  vm_settings__windows_operator = {
    "01" = {
      host_name                = local.pve_hosts["pve-01"]["host_name"]
      vm_id                    = 105
      managemt_nw_host_section = 18
      cpu_socket               = 1
      cpu_core                 = 2
      memory                   = 1024 * 4
      os_disk_size             = 40
    }
  }
}

resource "random_password" "vm_admin_password__windows_operator" {
  for_each = local.vm_settings__windows_operator

  # cloudbase-init requires passwords to be 20 characters or less (hardcoded)
  # https://github.com/cloudbase/cloudbase-init/issues/114
  # https://github.com/cloudbase/cloudbase-init/blob/4cbde8cac2408c75649038bd83900a2dc9edde06/cloudbaseinit/plugins/common/userdataplugins/cloudconfigplugins/users.py#L54
  length      = 20
  min_lower   = 3
  min_upper   = 3
  min_numeric = 3
  special     = false
}

resource "random_password" "vm_user_password__windows_operator" {
  for_each = local.vm_settings__windows_operator

  # cloudbase-init requires passwords to be 20 characters or less (hardcoded)
  # https://github.com/cloudbase/cloudbase-init/issues/114
  # https://github.com/cloudbase/cloudbase-init/blob/4cbde8cac2408c75649038bd83900a2dc9edde06/cloudbaseinit/plugins/common/userdataplugins/cloudconfigplugins/users.py#L54
  length      = 20
  min_lower   = 3
  min_upper   = 3
  min_numeric = 3
  special     = false
}

resource "terraform_data" "cloud_init_config__windows_operator" {
  for_each = local.vm_settings__windows_operator
  triggers_replace = [
    filesha1("cloud-init/${local.env}-wop_cloud-init.yaml.tftpl"),
    random_password.vm_admin_password__windows_operator[each.key],
    random_password.vm_user_password__windows_operator[each.key]
  ]

  connection {
    type        = "ssh"
    host        = local.pve_hosts[each.value.host_name].ip_address
    user        = local.machine_user
    private_key = base64decode(var.vm_ssh_private_key)
  }
  provisioner "file" {
    content = templatefile("cloud-init/${local.env}-wop_cloud-init.yaml.tftpl", {
      CI_HOSTNAME               = "${local.env}-wop-${format("%02d", tonumber(each.key))}",
      CI_ADMIN_PASSWORD         = random_password.vm_admin_password__windows_operator[each.key].result,
      CI_MACHINEUSER_NAME       = local.machine_user,
      CI_MACHINEUSER_PASSWORD   = random_password.vm_user_password__windows_operator[each.key].result,
      CI_MACHINEUSER_SSH_PUBKEY = base64decode(local.vm_ssh_public_key),
    })
    destination = "/tmp/${local.env}-wop-${format("%02d", tonumber(each.key))}_cloud-init.yaml"
  }
  provisioner "remote-exec" {
    inline = [
      "echo '${var.pve_user_password}' | sudo -S mv /tmp/${local.env}-wop-${format("%02d", tonumber(each.key))}_cloud-init.yaml /var/lib/vz/snippets/",
    ]
  }
}

resource "proxmox_vm_qemu" "windows_operator" {
  for_each   = local.vm_settings__windows_operator
  depends_on = [terraform_data.cloud_init_config__windows_operator]

  name               = "${local.env}-wop-${format("%02d", tonumber(each.key))}"
  target_node        = each.value.host_name
  vmid               = each.value.vm_id
  description        = "Windows VM to operate something. This VM is managed by Terraform."
  bios               = "ovmf"
  start_at_node_boot = true
  agent              = 1
  clone              = "winsrv-2025"
  full_clone         = true
  tags               = "${local.env};terraform;operator;windows-operator"
  qemu_os            = "win11"

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
  cicustom = "user=local:snippets/${local.env}-wop-${format("%02d", tonumber(each.key))}_cloud-init.yaml"

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

  // Note: Serial device is unnecessary

  vga {
    type = "std"
  }

  // EFI disk is undefined b/c cloned from template

  // Note: TPM v2.0 is necessary b/c using Windows 11+
  tpm_state {
    storage = local.vm_disk_storage
    version = "v2.0"
  }

  lifecycle {
    ignore_changes = [
      tags
    ]
  }
}

resource "ansible_group" "windows_operator" {
  name = "windows_operator"
  variables = {
    ansible_user                = local.machine_user
    ansible_connection          = "psrp"
    ansible_psrp_auth           = "kerberos"
    ansible_psrp_cert_validation = "ignore"
  }
}

resource "ansible_host" "windows_operator" {
  for_each = proxmox_vm_qemu.windows_operator

  name   = each.value.name
  groups = [ansible_group.windows_operator.name]
  variables = {
    ansible_host = each.value.ssh_host
  }
}
