locals {
  vm_settings__domain_controller = {
    "01" = {
      host_name                = local.pve_hosts["prod-prox-01"]["host_name"]
      vm_id                    = 106
      managemt_nw_host_section = 10
      cpu_socket               = 1
      cpu_core                 = 2
      memory                   = 1024 * 4
      os_disk_size             = 40
      ad_data_size             = 10
    }
  }
}

resource "random_password" "vm_admin_password__domain_controller" {
  for_each = local.vm_settings__domain_controller

  # cloudbase-init requires passwords to be 20 characters or less (hardcoded)
  # https://github.com/cloudbase/cloudbase-init/issues/114
  # https://github.com/cloudbase/cloudbase-init/blob/4cbde8cac2408c75649038bd83900a2dc9edde06/cloudbaseinit/plugins/common/userdataplugins/cloudconfigplugins/users.py#L54
  length      = 20
  min_lower   = 3
  min_upper   = 3
  min_numeric = 3
  special     = false
}

resource "random_password" "vm_user_password__domain_controller" {
  for_each = local.vm_settings__domain_controller

  # cloudbase-init requires passwords to be 20 characters or less (hardcoded)
  # https://github.com/cloudbase/cloudbase-init/issues/114
  # https://github.com/cloudbase/cloudbase-init/blob/4cbde8cac2408c75649038bd83900a2dc9edde06/cloudbaseinit/plugins/common/userdataplugins/cloudconfigplugins/users.py#L54
  length      = 20
  min_lower   = 3
  min_upper   = 3
  min_numeric = 3
  special     = false
}

resource "random_password" "ad_safemode_admin_password" {
  # cloudbase-init requires passwords to be 20 characters or less (hardcoded)
  # https://github.com/cloudbase/cloudbase-init/issues/114
  # https://github.com/cloudbase/cloudbase-init/blob/4cbde8cac2408c75649038bd83900a2dc9edde06/cloudbaseinit/plugins/common/userdataplugins/cloudconfigplugins/users.py#L54
  length      = 20
  min_lower   = 3
  min_upper   = 3
  min_numeric = 3
  special     = false
}

resource "terraform_data" "cloud_init_config__domain_controller" {
  for_each = local.vm_settings__domain_controller
  triggers_replace = [
    filesha1("cloud-init/${local.env}-adds_cloud-init.yaml.tftpl"),
    random_password.vm_admin_password__domain_controller[each.key],
    random_password.vm_user_password__domain_controller[each.key]
  ]

  connection {
    type        = "ssh"
    host        = local.pve_hosts[each.value.host_name].ip_address
    user        = local.machine_user
    private_key = base64decode(var.vm_ssh_private_key)
  }
  provisioner "file" {
    content = templatefile("cloud-init/${local.env}-adds_cloud-init.yaml.tftpl", {
      CI_HOSTNAME               = "${local.env}-adds-${format("%02d", tonumber(each.key))}",
      CI_ADMIN_PASSWORD         = random_password.vm_admin_password__domain_controller[each.key].result,
      CI_MACHINEUSER_NAME       = local.machine_user,
      CI_MACHINEUSER_PASSWORD   = random_password.vm_user_password__domain_controller[each.key].result,
      CI_MACHINEUSER_SSH_PUBKEY = base64decode(local.vm_ssh_public_key),
      AD_SAFEMODE_ADMIN_PASS    = random_password.ad_safemode_admin_password.result,
    })
    destination = "/tmp/${local.env}-adds-${format("%02d", tonumber(each.key))}_cloud-init.yaml"
  }
  provisioner "remote-exec" {
    inline = [
      "echo '${var.pve_user_password}' | sudo -S mv /tmp/${local.env}-adds-${format("%02d", tonumber(each.key))}_cloud-init.yaml /var/lib/vz/snippets/",
    ]
  }
}

resource "proxmox_vm_qemu" "domain_controller" {
  for_each   = local.vm_settings__domain_controller
  depends_on = [terraform_data.cloud_init_config__domain_controller]

  name               = "${local.env}-adds-${format("%02d", tonumber(each.key))}"
  target_node        = each.value.host_name
  vmid               = each.value.vm_id
  description        = "Active Directory domain contoller. This VM is managed by Terraform."
  bios               = "ovmf"
  start_at_node_boot = true
  agent              = 1
  clone              = "winsrv-2025"
  full_clone         = true
  tags               = "${local.env};terraform;domain-controller"
  qemu_os            = "win11"

  startup_shutdown {
    # 待機系を先に落とす（例: 2台あるときは、#1 -> 2 + 1 - 1 = 優先度 2、#2 -> 2 + 1 - 2 = 優先度 1）
    order            = length(local.vm_settings__domain_controller) + 1 - tonumber(each.key)
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
  cicustom = "user=local:snippets/${local.env}-adds-${format("%02d", tonumber(each.key))}_cloud-init.yaml"

  network {
    id     = 0
    model  = "virtio"
    bridge = local.vm_management_nw_bridge
  }

  ipconfig0 = "ip=${cidrhost(local.vm_management_nw_subnet_cidr, each.value.managemt_nw_host_section)}${"/${local.vm_management_nw_subnet_mask}"},gw=${local.vm_management_nw_default_gw}"

  disks {
    scsi {
      scsi0 {
        disk {
          size     = "${each.value.os_disk_size}G"
          storage  = local.vm_disk_storage
          iothread = true
        }
      }
      scsi1 {
        disk {
          size     = "${each.value.ad_data_size}G"
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

resource "ansible_group" "domain_computer" {
  name = "domain_computer"
  variables = {
    ansible_domain_dn = "DC=ad,DC=labo,DC=clov3r,DC=cc"
  }
}

resource "ansible_group" "domain_controller" {
  name = "domain_controller"
  variables = {
    ansible_user                   = local.machine_user
    ansible_connection             = "psrp"
    ansible_psrp_auth              = "kerberos"
    ansible_psrp_protocol          = "http"
    ansible_psrp_negotiate_service = "HTTP"
    ansible_psrp_cert_validation   = "ignore"
  }
}

resource "ansible_host" "domain_controller" {
  for_each = proxmox_vm_qemu.domain_controller

  name   = each.value.name
  groups = [ansible_group.domain_computer.name, ansible_group.domain_controller.name]
  variables = {
    ansible_host                             = regex("ip=([0-9.]+)", each.value.ipconfig0)[0]
    ansible_psrp_negotiate_hostname_override = "${each.value.name}.ad.labo.clov3r.cc"
  }
}
