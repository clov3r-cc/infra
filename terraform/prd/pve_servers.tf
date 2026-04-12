resource "ansible_group" "pve_server" {
  name = "pve_server"
  variables = {
    ansible_user                 = local.machine_user
    ansible_ssh_private_key_file = local.ansible_ssh_private_key_path
  }
}

resource "ansible_host" "pve_server" {
  for_each = local.pve_hosts

  name   = each.key
  groups = [ansible_group.pve_server.name]
  variables = {
    ansible_host = each.value.ip_address
  }
}
