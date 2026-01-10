locals {
  vm_settings__desktop = {
    "01" = {
      host_name                = local.pve_hosts["pve-01"]["host_name"]
      vm_id                    = 105
      managemt_nw_host_section = 18
      cpu_socket               = 1
      cpu_core                 = 2
      memory                   = 1024 * 4
      os_disk_size             = 50
    }
  }
}

resource "proxmox_vm_qemu" "desktop" {
  for_each = local.vm_settings__desktop

  name               = "${local.env}-dsk-${format("%02d", tonumber(each.key))}"
  target_node        = each.value.host_name
  vmid               = each.value.vm_id
  description        = "Desktop to use GUI. This VM is managed by Terraform."
  bios               = "seabios"
  start_at_node_boot = true
  agent              = 1
  tags               = "${local.env};terraform;windows;desktop"
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

  lifecycle {
    ignore_changes = [
      tags
    ]
  }
}
