# NOTE: account_id、zone_id は非シークレット
# https://github.com/cloudflare/wrangler-legacy/issues/209#issuecomment-541654484

#region Cloudflare

data "cloudflare_account" "me" {
  account_id = "fff06038a70892193e0fa1e9e270436a"
}

data "cloudflare_zone" "clov3r-cc" {
  zone_id = "b52fd73ec52e35fea1807a173e33e93a"
}

#endregion

#region Oracle Cloud

# ap-osaka-1 has only one availability domain
data "oci_identity_availability_domain" "ad" {
  compartment_id = local.oracle_cloud_tenancy_id
  ad_number      = 1
}

#endregion


locals {
  #region Proxmox VE

  pve_hosts = {
    "prod-prox-01" = {
      host_name  = "prod-prox-01"
      ip_address = "192.168.21.2"
    }
  }

  env = "prod"

  machine_user = "machine-user"

  vm_template__alma = "alma-10.1"
  vm_disk_storage   = "local-lvm"
  vm_ssh_public_key = <<EOT
c3NoLWVkMjU1MTkgQUFBQUMzTnphQzFsWkRJMU5URTVBQUFBSU1IWitzblhERk5WSzg5c2ZLQXEx
VUxFSTV5Ukx4cVdRSFlpVlRHVVZsYjgK
EOT

  # Public network configuration
  vm_service_nw_bridge      = "vmbr0"
  vm_service_nw_subnet_cidr = "192.168.20.0/24"
  vm_service_nw_subnet_mask = split("/", local.vm_service_nw_subnet_cidr)[1]
  vm_service_nw_default_gw  = cidrhost(local.vm_service_nw_subnet_cidr, 1)
  # Internal network configuration
  vm_management_nw_bridge      = "vmbr1"
  vm_management_nw_subnet_cidr = "192.168.21.0/24"
  vm_management_nw_subnet_mask = split("/", local.vm_management_nw_subnet_cidr)[1]
  vm_management_nw_default_gw  = cidrhost(local.vm_management_nw_subnet_cidr, 1)
  # Zabbix Server Heartbeat network configuration
  zabbix_server_heartbeat_nw_bridge      = "vmbr2"
  zabbix_server_heartbeat_nw_subnet_cidr = "192.168.91.0/29"
  zabbix_server_heartbeat_nw_subnet_mask = split("/", local.zabbix_server_heartbeat_nw_subnet_cidr)[1]

  ansible_ssh_private_key_path = "/home/${local.machine_user}/.ssh/id_ed25519"

  #endregion

  #region Oracle Cloud

  oracle_cloud_tenancy_id = "ocid1.tenancy.oc1..aaaaaaaa3vcsovo36fpa7kf42sljmsypxgwrp37lowwl27g5n7pgy765krba"

  #endregion
}
