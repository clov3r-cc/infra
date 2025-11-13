output "zabbix_servers" {
  value = [for vm in proxmox_vm_qemu.server : {
    vm_name = vm.name
    ip0     = vm.ssh_host
  }]
}
