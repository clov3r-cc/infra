locals {
  pve_hosts = {
    "pve-01" = {
      host_name      = "pve-01"
      console_domain = "pxmx01-mng.${cloudflare_zone.clov3r-cc.zone}"
    }
  }

  vm_template        = "alma-9"
  vm_os_disk_storage = "local-lvm"

  # Public network configuration
  vm_public-net_bridge      = "vmbr0"
  vm_public-net_subnet_cidr = "192.168.102.131/24"
  # Internal network configuration
  vm_internal-net_bridge      = "vmbr1"
  vm_internal-net_subnet_cidr = "192.168.8.0/24"
}

resource "random_password" "vm_user_password" {
  length      = 16
  min_lower   = 3
  min_upper   = 3
  min_numeric = 3
  min_special = 3
}

module "k8s_worker_nodes__prod" {
  source = "./modules/k8s_nodes"

  env_name = "prod"

  vm_user            = var.vm_user
  vm_user_password   = random_password.vm_user_password.result
  vm_ssh_public_key  = var.vm_ssh_public_key
  vm_template        = local.vm_template
  vm_os_disk_storage = local.vm_os_disk_storage

  gateway_allocated_host            = local.pve_hosts["pve-01"]["host_name"]
  gateway_vm_id                     = 801
  gateway_memory                    = 2048
  gateway_sockets                   = 1
  gateway_cores                     = 2
  gateway_public-net_bridge         = local.vm_public-net_bridge
  gateway_public-net_subnet_cidr    = local.vm_public-net_subnet_cidr
  gateway_internal-net_bridge       = local.vm_internal-net_bridge
  gateway_internal-net_subnet_cidr  = local.vm_internal-net_subnet_cidr
  gateway_internal-net_host-section = 2
  gateway_os_disk_size              = 20

  control_plane_allocated_host = {
    1 = local.pve_hosts["pve-01"]["host_name"]
    2 = local.pve_hosts["pve-01"]["host_name"]
    3 = local.pve_hosts["pve-01"]["host_name"]
  }
  control_plane_first_vm_id                     = 811
  control_plane_memory                          = 1024 * 3
  control_plane_sockets                         = 1
  control_plane_cores                           = 3
  control_plane_internal-net_bridge             = local.vm_internal-net_bridge
  control_plane_internal-net_subnet_cidr        = local.vm_internal-net_subnet_cidr
  control_plane_first_internal-net_host-section = 11
  control_plane_os_disk_size                    = 20

  worker_allocated_host = {
    1 = local.pve_hosts["pve-01"]["host_name"]
    2 = local.pve_hosts["pve-01"]["host_name"]
    3 = local.pve_hosts["pve-01"]["host_name"]
  }
  worker_first_vm_id                     = 821
  worker_memory                          = 1024 * 6
  worker_sockets                         = 1
  worker_cores                           = 3
  worker_internal-net_bridge             = local.vm_internal-net_bridge
  worker_internal-net_subnet_cidr        = local.vm_internal-net_subnet_cidr
  worker_first_internal-net_host-section = 21
  worker_os_disk_size                    = 20
}
