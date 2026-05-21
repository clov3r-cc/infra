resource "ansible_group" "desktop" {
  name = "desktop"
}

resource "ansible_host" "desktop" {
  name   = "${local.env}-dsk-01"
  groups = [ansible_group.internal.name, ansible_group.desktop.name, ansible_group.zabbix_server.name, ansible_group.zabbix_server__qdevice.name]
  variables = {
    ansible_host    = cidrhost(local.vm_internal_nw_subnet_cidr, 10)
    heartbeat_nw_ip = cidrhost(local.zabbix_server_heartbeat_nw_subnet_cidr, 3)
    host_index      = 1
    vm_id           = 403
  }
}
