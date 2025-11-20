resource "oci_core_vcn" "my_vcn" {
  compartment_id                   = local.oracle_cloud_tenancy_id
  cidr_blocks                      = "10.0.0.0/16"
  display_name                     = "my_vcn"
  dns_label                        = "clov3r"
  is_ipv6enabled                   = false
  is_oracle_gua_allocation_enabled = false
}
