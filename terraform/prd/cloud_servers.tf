locals {
  oracle_cloud_vm_instance_shape = "VM.Standard.A1.Flex"
}

resource "oci_core_vcn" "my_vcn" {
  compartment_id = local.oracle_cloud_tenancy_id
  cidr_blocks    = ["10.0.21.0/24"]
  display_name   = "prd-vcn-01"
  is_ipv6enabled = false
}

resource "oci_core_internet_gateway" "my_vcn_internet_gateway" {
  compartment_id = local.oracle_cloud_tenancy_id
  vcn_id         = oci_core_vcn.my_vcn.id
  enabled        = true
  display_name   = "prd-igw-01"
}

resource "oci_core_subnet" "my_vcn_subnet" {
  compartment_id = local.oracle_cloud_tenancy_id
  vcn_id         = oci_core_vcn.my_vcn.id
  route_table_id = oci_core_route_table.my_vcn_route_table.id
  cidr_block     = "10.0.21.0/24"
  display_name   = "prd-sbn-01"
}

resource "oci_core_route_table" "my_vcn_route_table" {
  compartment_id = local.oracle_cloud_tenancy_id
  vcn_id         = oci_core_vcn.my_vcn.id
  display_name   = "prd-rtb-01"

  route_rules {
    destination       = "0.0.0.0/0"
    destination_type  = "CIDR_BLOCK"
    network_entity_id = oci_core_internet_gateway.my_vcn_internet_gateway.id
  }
}

# NOTE: Remove all rules from default security list!

resource "oci_core_network_security_group" "my_vcn_nw_sg" {
  compartment_id = local.oracle_cloud_tenancy_id
  vcn_id         = oci_core_vcn.my_vcn.id
  display_name   = "prd-nsg-01"
}

resource "oci_core_network_security_group_security_rule" "my_vcn_nw_sg__egress__allow_all_traffics" {
  network_security_group_id = oci_core_network_security_group.my_vcn_nw_sg.id
  stateless                 = false
  description               = "Allow all traffics on egress"
  direction                 = "EGRESS"
  destination_type          = "CIDR_BLOCK"
  destination               = "0.0.0.0/0"
  protocol                  = "all"
}

resource "oci_core_network_security_group_security_rule" "my_vcn_nw_sg__ingress__allow_ssh_traffics" {
  network_security_group_id = oci_core_network_security_group.my_vcn_nw_sg.id
  stateless                 = false
  description               = "Allow SSH traffics from the same subnet on ingress"
  direction                 = "INGRESS"
  source_type               = "CIDR_BLOCK"
  source                    = oci_core_subnet.my_vcn_subnet.cidr_block
  protocol                  = "6" // TCP
  tcp_options {
    destination_port_range {
      min = 22
      max = 22
    }
  }
}

resource "oci_core_network_security_group_security_rule" "my_vcn_nw_sg__ingress__allow_icmp_traffics" {
  network_security_group_id = oci_core_network_security_group.my_vcn_nw_sg.id
  stateless                 = false
  description               = "Allow ICMP traffics from anywhere on ingress"
  direction                 = "INGRESS"
  source_type               = "CIDR_BLOCK"
  source                    = "0.0.0.0/0"
  protocol                  = "1" // ICMP
}

# NOTE: https://docs.oracle.com/en-us/iaas/images/
data "oci_core_images" "images" {
  compartment_id           = local.oracle_cloud_tenancy_id
  operating_system         = "Oracle Linux"
  operating_system_version = "10"
  shape                    = local.oracle_cloud_vm_instance_shape
  sort_by                  = "TIMECREATED"
  sort_order               = "DESC"
}

resource "random_password" "vm_user_password__cloud_server" {
  length      = 30
  min_lower   = 3
  min_upper   = 3
  min_numeric = 3
  special     = false
}

resource "oci_core_instance" "cloud_server" {
  availability_domain = data.oci_identity_availability_domain.ad.name
  compartment_id      = local.oracle_cloud_tenancy_id
  display_name        = "prd-csv-01"
  shape               = local.oracle_cloud_vm_instance_shape

  shape_config {
    ocpus         = 2
    memory_in_gbs = 4
  }

  create_vnic_details {
    subnet_id                 = oci_core_subnet.my_vcn_subnet.id
    assign_public_ip          = true
    assign_private_dns_record = false
    nsg_ids                   = [oci_core_network_security_group.my_vcn_nw_sg.id]
  }

  source_details {
    source_type = "image"
    source_id   = lookup(data.oci_core_images.images.images[0], "id")
  }

  metadata = {
    ssh_authorized_keys = base64decode(local.vm_ssh_public_key)
    user_data = base64encode(templatefile("cloud-init/${local.env}-csv_userdata.sh.tftpl", {
      CI_MACHINEUSER_NAME       = local.machine_user,
      CI_MACHINEUSER_PASSWORD   = random_password.vm_user_password__cloud_server.result,
      CI_MACHINEUSER_SSH_PUBKEY = base64decode(local.vm_ssh_public_key),
    }))
  }

  lifecycle {
    ignore_changes = [metadata.user_data]
  }
}

resource "ansible_group" "cloud_server" {
  name = "cloud_server"
  variables = {
    ansible_user                 = local.machine_user
    ansible_ssh_private_key_file = local.ansible_ssh_private_key_path
  }
}

resource "ansible_host" "cloud_server" {
  name   = oci_core_instance.cloud_server.display_name
  groups = [ansible_group.cloud_server.name]
  variables = {
    ansible_host = oci_core_instance.cloud_server.private_ip
  }
}
