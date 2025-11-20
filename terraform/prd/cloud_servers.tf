resource "oci_core_vcn" "my_vcn" {
  compartment_id                   = local.oracle_cloud_tenancy_id
  cidr_blocks                      = ["10.0.21.0/24"]
  display_name                     = "my_vcn__prod"
  dns_label                        = "clov3r"
  is_ipv6enabled                   = false
  is_oracle_gua_allocation_enabled = false
}

resource "oci_core_internet_gateway" "my_vcn_internet_gateway" {
  compartment_id = local.oracle_cloud_tenancy_id
  vcn_id         = oci_core_vcn.my_vcn.id
  enabled        = true
  display_name   = "my_vcn_internet_gateway__prod"
}

resource "oci_core_subnet" "my_vcn_subnet" {
  compartment_id      = local.oracle_cloud_tenancy_id
  vcn_id              = oci_core_vcn.my_vcn.id
  availability_domain = data.oci_identity_availability_domains.ad.compartment_id
  cidr_block          = "10.0.21.0/24"
  display_name        = "my_vcn_subnet__prod"
  dns_label           = "prod"
}
