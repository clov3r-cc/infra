output "zabbix_servers" {
  value = [for vm in proxmox_vm_qemu.server : {
    host_name   = vm.current_node
    id          = vm.vmid
    name        = vm.name
    description = vm.description
    ethernet_adapters = {
      ip0 = {
        bridge = vm.network[0].bridge
        config = vm.ipconfig0
      }
      ip1 = {
        bridge = vm.network[1].bridge
        config = vm.ipconfig1
      }
    }
  }]
}
