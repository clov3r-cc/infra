#region Proxmox VE

output "zabbix_servers__prd" {
  value = [for vm in proxmox_vm_qemu.zabbix_server : {
    host_name   = vm.current_node
    id          = vm.vmid
    name        = vm.name
    description = vm.description
    ethernet_adapters = {
      ip0 = {
        bridge     = vm.network[0].bridge
        ip_address = trimprefix(split(",", vm.ipconfig0)[0], "ip=")
      }
      ip1 = {
        bridge     = vm.network[1].bridge
        ip_address = trimprefix(split(",", vm.ipconfig1)[0], "ip=")
      }
    }
  }]
}

output "linux_operators__prd" {
  value = [for vm in proxmox_vm_qemu.linux_operator : {
    host_name   = vm.current_node
    id          = vm.vmid
    name        = vm.name
    description = vm.description
    ethernet_adapters = {
      ip0 = {
        bridge          = vm.network[0].bridge
        ip_address      = trimprefix(split(",", vm.ipconfig0)[0], "ip=")
        default_gateway = trimprefix(split(",", vm.ipconfig0)[1], "gw=")
      }
      ip1 = {
        bridge     = vm.network[1].bridge
        ip_address = trimprefix(split(",", vm.ipconfig1)[0], "ip=")
      }
    }
  }]
}

# TODO: Fix me
# output "prod__k8s_gateway_node" {
#   value = module.prod__k8s_nodes.gateway
# }

# output "prod__k8s_worker_nodes" {
#   value = module.prod__k8s_nodes.worker_nodes
# }

# output "prod__k8s_control_plane_nodes" {
#   value = module.prod__k8s_nodes.control_plane_nodes
# }

#endregion

#region Oracle Cloud

output "oci_identity_availability_domain" {
  value = data.oci_identity_availability_domain.ad
}

output "cloud-server__prd" {
  value = {
    id        = oci_core_instance.cloud_server.id
    host_name = oci_core_instance.cloud_server.display_name
    ethernet_adapters = {
      ip0 = oci_core_instance.cloud_server.private_ip
    }
  }
}

#endregion
