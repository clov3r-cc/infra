locals {
  pve_hosts = {
    "pve-01" = {
      host_name      = "pve-01"
      console_domain = "pxmx01-mng.${cloudflare_zone.clov3r-cc.zone}"
    }
  }

  vm_template        = "alma-9"
  vm_os_disk_storage = "local-lvm"

  # Internal network configuration
  vm_internal-net_bridge      = "vmbr1"
  vm_internal-net_subnet_cidr = "192.168.8.0/24"
  # Public network configuration
  vm_public-net_bridge      = "vmbr0"
  vm_public-net_subnet_ipv4 = "192.168.102.131"
  vm_public-net_subnet_cidr = "${local.vm_public-net_subnet_ipv4}/24"
}

resource "random_password" "vm_user_password" {
  length      = 16
  min_lower   = 3
  min_upper   = 3
  min_numeric = 3
  min_special = 3
}

# module "k8s-gateway-nodes" {
#   source = "./modules/k8s_node_vm"

#   env_name                    = "prod"
#   vm_category                 = "gw"
#   vm_template                 = local.vm_template
#   vm_user                     = var.vm_user
#   vm_os_disk_storage          = local.vm_os_disk_storage
#   vm_internal-net_bridge      = local.vm_internal-net_bridge
#   vm_public-net_bridge        = local.vm_public-net_bridge
#   vm_internal-net_subnet_cidr = local.vm_internal-net_subnet_cidr
#   vm_public-net_subnet_cidr   = local.vm_public-net_subnet_cidr
#   ssh_public_key              = var.ssh_public_key
#   nodes = [
#     {
#       vmid                      = 801,
#       target_node               = local.pve_hosts["pve01"]["host_name"],
#       memory                    = 1024,
#       sockets                   = 1,
#       cores                     = 1,
#       internal-net_host-section = 2,
#       public-net_host-section   = 131,
#       disk_size                 = "10G"
#     }
#   ]
# }

# module "k8s-controller-plane-nodes" {
#   source = "./modules/k8s_node_vm"

#   env_name                    = "prod"
#   vm_category                 = "cp"
#   vm_template                 = local.vm_template
#   vm_user                     = var.vm_user
#   vm_os_disk_storage          = local.vm_os_disk_storage
#   vm_internal-net_bridge      = local.vm_internal-net_bridge
#   vm_public-net_bridge        = local.vm_public-net_bridge
#   vm_internal-net_subnet_cidr = local.vm_internal-net_subnet_cidr
#   vm_public-net_subnet_cidr   = local.vm_public-net_subnet_cidr
#   ssh_public_key              = var.ssh_public_key
#   nodes = [
#     {
#       vmid                      = 811,
#       target_node               = local.pve_hosts["pve01"]["host_name"],
#       memory                    = 3072,
#       sockets                   = 1,
#       cores                     = 3,
#       internal-net_host-section = 11,
#       disk_size                 = "20G"
#     }
#   ]
# }

# module "k8s-worker-nodes" {
#   source = "./modules/k8s_node_vm"

#   env_name                    = "prod"
#   vm_category                 = "wk"
#   vm_template                 = local.vm_template
#   vm_user                     = var.vm_user
#   vm_os_disk_storage          = local.vm_os_disk_storage
#   vm_internal-net_bridge      = local.vm_internal-net_bridge
#   vm_public-net_bridge        = local.vm_public-net_bridge
#   vm_internal-net_subnet_cidr = local.vm_internal-net_subnet_cidr
#   vm_public-net_subnet_cidr   = local.vm_public-net_subnet_cidr
#   ssh_public_key              = var.ssh_public_key
#   nodes = [
#     {
#       vmid                      = 821,
#       target_node               = local.pve_hosts["pve01"]["host_name"],
#       memory                    = 6144,
#       sockets                   = 1,
#       cores                     = 4,
#       internal-net_host-section = 21,
#       disk_size                 = "20G"
#     }
#   ]
# }

module "k8s_worker_nodes__prod" {
  source = "./modules/k8s_nodes"

  env_name = "prod"

  worker_allocated_host = {
    1 = local.pve_hosts["pve-01"]["host_name"]
  }
  vm_user            = var.vm_user
  vm_user_password   = random_password.vm_user_password.result
  vm_ssh_public_key  = var.vm_ssh_public_key
  vm_template        = local.vm_template
  vm_os_disk_storage = local.vm_os_disk_storage

  worker_first_vm_id                     = 821
  worker_memory                          = 2048
  worker_sockets                         = 1
  worker_cores                           = 3
  worker_internal-net_bridge             = local.vm_internal-net_bridge
  worker_internal-net_subnet_cidr        = local.vm_internal-net_subnet_cidr
  worker_first_internal-net_host-section = 21
  worker_os_disk_size                    = "20G"
}
