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
  source                    = "0.0.0.0/0"
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
  source                    = "0.0.0.0/0"
  protocol                  = "1" // ICMP
}
