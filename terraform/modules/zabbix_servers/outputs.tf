output "zabbix_servers" {
  value = [for vm in proxmox_vm_qemu.server : {
    host_name   = vm.current_node
    id          = vm.vmid
    name        = vm.name
    description = vm.description
    ethernet_adapters = {
      ip0 = merge(
        { bridge = vm.network[0].bridge },
        regex("ip=(?P<ip_address>[.*]),gw=(?P<default_gateway>[.*])", vm.ipconfig0)
      )
    }
  }]
}
