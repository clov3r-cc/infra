resource "ansible_group" "dmz" {
  name     = "dmz"
  children = [ansible_group.tailscale_server.name, ansible_group.dns_server.name]
}

resource "ansible_group" "internal" {
  name     = "internal"
  children = [ansible_group.zabbix_server.name]
}
