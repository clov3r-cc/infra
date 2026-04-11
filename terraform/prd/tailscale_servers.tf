locals {
  tailscale_servers = {
    "01" = { ip = cidrhost(local.vm_dmz_nw_subnet_cidr, 4) }
    "02" = { ip = cidrhost(local.vm_dmz_nw_subnet_cidr, 5) }
  }
}

resource "ansible_group" "tailscale_server" {
  name = "tailscale_server"
  variables = {
    ansible_user                 = local.machine_user
    ansible_ssh_private_key_file = local.ansible_ssh_private_key_path
  }
}

resource "ansible_host" "tailscale_server" {
  for_each = local.tailscale_servers

  name   = "${local.env}-tal-${each.key}"
  groups = [ansible_group.tailscale_server.name]
  variables = {
    ansible_host = each.value.ip
    host_index   = tonumber(each.key)
  }
}
