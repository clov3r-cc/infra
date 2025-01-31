output "gateway" {
  value = {
    vm_name = proxmox_vm_qemu.gateway.name
    ip0     = proxmox_vm_qemu.gateway.ssh_host
  }
}

output "control_plane_nodes" {
  value = [for vm in proxmox_vm_qemu.control_plane : {
    vm_name = vm.name
    ip0     = vm.ssh_host
  }]
}

output "worker_nodes" {
  value = [for vm in proxmox_vm_qemu.worker : {
    vm_name = vm.name
    ip0     = vm.ssh_host
  }]
}
