locals {
  vyos_router_settings = {
    "01" = {
      dmz_nw_ip                = cidrhost(local.vm_dmz_nw_subnet_cidr, 2)
      vyos_eth0_address        = "192.168.20.4/29"
      vyos_eth1_address        = "${cidrhost(local.vm_dmz_nw_subnet_cidr, 2)}/${local.vm_dmz_nw_subnet_mask}"
      vyos_eth2_address        = "${cidrhost(local.vm_service_nw_subnet_cidr, 4)}/${local.vm_service_nw_subnet_mask}"
      vyos_eth3_address        = "${cidrhost(local.vm_internal_nw_subnet_cidr, 4)}/${local.vm_internal_nw_subnet_mask}"
      vyos_vrrp_priority       = 150
      vyos_vrrp_expected_state = "MASTER"
    }
    "02" = {
      dmz_nw_ip                = cidrhost(local.vm_dmz_nw_subnet_cidr, 3)
      vyos_eth0_address        = "192.168.20.5/29"
      vyos_eth1_address        = "${cidrhost(local.vm_dmz_nw_subnet_cidr, 3)}/${local.vm_dmz_nw_subnet_mask}"
      vyos_eth2_address        = "${cidrhost(local.vm_service_nw_subnet_cidr, 5)}/${local.vm_service_nw_subnet_mask}"
      vyos_eth3_address        = "${cidrhost(local.vm_internal_nw_subnet_cidr, 5)}/${local.vm_internal_nw_subnet_mask}"
      vyos_vrrp_priority       = 100
      vyos_vrrp_expected_state = "BACKUP"
    }
  }
}

resource "ansible_group" "vyos_router" {
  name = "vyos_router"
  variables = {
    ansible_network_os         = "vyos.vyos.vyos"
    ansible_connection         = "ansible.netcommon.network_cli"
    ansible_user               = "vyos"
    ansible_python_interpreter = "python3"
  }
}

resource "ansible_host" "vyos_router" {
  for_each = local.vyos_router_settings

  name   = "prd-vyo-${each.key}"
  groups = [ansible_group.vyos_router.name]
  variables = {
    ansible_host             = each.value.dmz_nw_ip
    vyos_eth0_address        = each.value.vyos_eth0_address
    vyos_eth1_address        = each.value.vyos_eth1_address
    vyos_eth2_address        = each.value.vyos_eth2_address
    vyos_eth3_address        = each.value.vyos_eth3_address
    vyos_vrrp_priority       = each.value.vyos_vrrp_priority
    vyos_vrrp_expected_state = each.value.vyos_vrrp_expected_state
  }
}
