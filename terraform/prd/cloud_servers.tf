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
  description               = "SSH traffics on ingress"
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
  description               = "ICMP traffics on ingress"
  direction                 = "INGRESS"
  source_type               = "CIDR_BLOCK"
  source                    = oci_core_subnet.my_vcn_subnet.cidr_block
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
    assign_public_ip          = false
    assign_private_dns_record = false
    nsg_ids                   = [oci_core_network_security_group.my_vcn_nw_sg.id]
  }

  source_details {
    source_type = "image"
    source_id   = lookup(data.oci_core_images.images.images[0], "id")
  }

  metadata = {
    ssh_authorized_keys = base64decode(local.vm_ssh_public_key)
    locale              = "en_US.UTF-8"
    timezone            = "Asia/Tokyo"
    packages            = ["glibc-all-langpacks", "langpacks-en", "vim-enhanced"]
  }
}
