output "zabbix_servers__prd" {
  value = [for vm in proxmox_vm_qemu.zabbix_server : {
    host_name   = vm.current_node
    id          = vm.vmid
    name        = vm.name
    description = vm.description
    ethernet_adapters = {
      ip0 = merge(
        { bridge = vm.network[0].bridge },
        # (?P<name>x):	named capture group, named name, for sub-pattern x
        # https://developer.hashicorp.com/terraform/language/functions/regex
        regex("ip=(?P<ip_address>.*),gw=(?P<default_gateway>.*)", vm.ipconfig0)
      )
    }
  }]
}

output "ansible_players__prd" {
  value = [for vm in proxmox_vm_qemu.ansible_player : {
    host_name   = vm.current_node
    id          = vm.vmid
    name        = vm.name
    description = vm.description
    ethernet_adapters = {
      ip0 = merge(
        { bridge = vm.network[0].bridge },
        # (?P<name>x):	named capture group, named name, for sub-pattern x
        # https://developer.hashicorp.com/terraform/language/functions/regex
        regex("ip=(?P<ip_address>.*),gw=(?P<default_gateway>.*)", vm.ipconfig0)
      )
    }
  }]
}

# TODO: Remove this
output "list_ads" {
  value = data.oci_identity_availability_domains.ad.availability_domains
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
