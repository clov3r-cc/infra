locals {
  pve_hosts = {
    "pve-01" = {
      host_name      = "pve-01"
      console_domain = "192.168.120.2:8006"
    }
  }

  machine_user = "machine-user"

  vm_template__alma  = "alma-10.0"
  vm_os_disk_storage = "local-lvm"
  vm_ssh_public_key  = "AAAAC3NzaC1lZDI1NTE5AAAAIMHZ+snXDFNVK89sfKAq1ULEI5yRLxqWQHYiVTGUVlb8"

  # Public network configuration
  vm_service_nw_bridge      = "vmbr0"
  vm_service_nw_subnet_cidr = "192.168.20.0/24"
  # Internal network configuration
  vm_management_nw_bridge      = "vmbr1"
  vm_management_nw_subnet_cidr = "192.168.120.0/24"
}

module "prod__zabbix_servers" {
  source = "./modules/zabbix_servers"

  env_name = "prod"

  pve_user          = local.machine_user
  pve_user_password = var.pve_user_password

  vm_template        = local.vm_template__alma
  vm_user            = local.machine_user
  vm_ssh_public_key  = local.vm_ssh_public_key
  vm_ssh_private_key = var.vm_ssh_private_key
  vm_os_disk_storage = local.vm_os_disk_storage

  server_allocated_host = {
    1 = local.pve_hosts["pve-01"]["host_name"]
    2 = local.pve_hosts["pve-01"]["host_name"]
  }
  server_first_vm_id                      = 102
  server_memory                           = 1024 * 3
  server_sockets                          = 1
  server_cores                            = 3
  server_management_nw_bridge             = local.vm_management_nw_bridge
  server_management_nw_subnet_cidr        = local.vm_management_nw_subnet_cidr
  server_first_management_nw_host-section = 14
  server_os_disk_size                     = 30
}

# TODO: Fix me
# module "prod__k8s_nodes" {
#   source = "./modules/k8s_nodes"

#   env_name = "prod"

#   pve_user          = local.machine_user
#   pve_user_password = var.pve_user_password

#   vm_template         = local.vm_template
#   vm_user             = local.machine_user
#   vm_ssh_public_key   = local.vm_ssh_public_key
#   vm_ssh_private_key  = var.vm_ssh_private_key
#   vm_os_disk_storage  = local.vm_os_disk_storage
#   rhel_org            = var.rhel_org
#   rhel_activation_key = var.rhel_activation_key

#   gateway_allocated_host            = local.pve_hosts["pve-01"]["host_name"]
#   gateway_vm_id                     = 801
#   gateway_memory                    = 2048
#   gateway_sockets                   = 1
#   gateway_cores                     = 2
#   gateway_public-net_bridge         = local.vm_public-net_bridge
#   gateway_public-net_subnet_cidr    = local.vm_public-net_subnet_cidr
#   gateway_internal-net_bridge       = local.vm_internal-net_bridge
#   gateway_internal-net_subnet_cidr  = local.vm_internal-net_subnet_cidr
#   gateway_internal-net_host-section = 1
#   gateway_os_disk_size              = 20

#   control_plane_allocated_host = {
#     1 = local.pve_hosts["pve-01"]["host_name"]
#   }
#   control_plane_first_vm_id                     = 811
#   control_plane_memory                          = 1024 * 3
#   control_plane_sockets                         = 1
#   control_plane_cores                           = 3
#   control_plane_internal-net_bridge             = local.vm_internal-net_bridge
#   control_plane_internal-net_subnet_cidr        = local.vm_internal-net_subnet_cidr
#   control_plane_first_internal-net_host-section = 11
#   control_plane_os_disk_size                    = 20

#   worker_allocated_host = {
#     1 = local.pve_hosts["pve-01"]["host_name"]
#   }
#   worker_first_vm_id                     = 821
#   worker_memory                          = 1024 * 6
#   worker_sockets                         = 1
#   worker_cores                           = 3
#   worker_internal-net_bridge             = local.vm_internal-net_bridge
#   worker_internal-net_subnet_cidr        = local.vm_internal-net_subnet_cidr
#   worker_first_internal-net_host-section = 21
#   worker_os_disk_size                    = 20
# }
