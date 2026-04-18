locals {
  router_settings = {
    "01" = {
      dmz_nw_ip           = cidrhost(local.vm_dmz_nw_subnet_cidr, 2)
      eth0_address        = "192.168.20.4/29"
      eth1_address        = "${cidrhost(local.vm_dmz_nw_subnet_cidr, 2)}/${local.vm_dmz_nw_subnet_mask}"
      eth2_address        = "${cidrhost(local.vm_service_nw_subnet_cidr, 4)}/${local.vm_service_nw_subnet_mask}"
      eth3_address        = "${cidrhost(local.vm_internal_nw_subnet_cidr, 4)}/${local.vm_internal_nw_subnet_mask}"
      vrrp_priority       = 150
      vrrp_expected_state = "MASTER"
    }
    "02" = {
      dmz_nw_ip           = cidrhost(local.vm_dmz_nw_subnet_cidr, 3)
      eth0_address        = "192.168.20.5/29"
      eth1_address        = "${cidrhost(local.vm_dmz_nw_subnet_cidr, 3)}/${local.vm_dmz_nw_subnet_mask}"
      eth2_address        = "${cidrhost(local.vm_service_nw_subnet_cidr, 5)}/${local.vm_service_nw_subnet_mask}"
      eth3_address        = "${cidrhost(local.vm_internal_nw_subnet_cidr, 5)}/${local.vm_internal_nw_subnet_mask}"
      vrrp_priority       = 100
      vrrp_expected_state = "BACKUP"
    }
  }
}

resource "ansible_group" "router" {
  name = "router"
  variables = {
    ansible_user                 = local.machine_user
    ansible_ssh_private_key_file = local.ansible_ssh_private_key_path
  }
}

resource "ansible_host" "router" {
  for_each = local.router_settings

  name   = "prd-vyo-${each.key}"
  groups = [ansible_group.router.name]
  variables = {
    ansible_host        = each.value.dmz_nw_ip
    eth0_address        = each.value.eth0_address
    eth1_address        = each.value.eth1_address
    eth2_address        = each.value.eth2_address
    eth3_address        = each.value.eth3_address
    vrrp_priority       = each.value.vrrp_priority
    vrrp_expected_state = each.value.vrrp_expected_state
  }
}
