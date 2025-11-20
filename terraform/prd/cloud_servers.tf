# resource "oci_core_vcn" "my_vcn" {
#   compartment_id = local.oracle_cloud_tenancy_id
#   cidr_blocks    = ["10.0.21.0/24"]
#   display_name   = "my_vcn__prod"
#   dns_label      = "clov3r"
#   is_ipv6enabled = false
# }

# resource "oci_core_internet_gateway" "my_vcn_internet_gateway" {
#   compartment_id = local.oracle_cloud_tenancy_id
#   vcn_id         = oci_core_vcn.my_vcn.id
#   enabled        = true
#   display_name   = "my_vcn_internet_gateway__prod"
# }

# resource "oci_core_subnet" "my_vcn_subnet" {
#   compartment_id      = local.oracle_cloud_tenancy_id
#   vcn_id              = oci_core_vcn.my_vcn.id
#   availability_domain = data.oci_identity_availability_domains.ad.id
#   cidr_block          = "10.0.21.0/24"
#   display_name        = "my_vcn_subnet__prod"
#   dns_label           = "prod"
# }

# resource "oci_core_route_table" "my_vcn_route_table" {
#   compartment_id = local.oracle_cloud_tenancy_id
#   vcn_id         = oci_core_vcn.my_vcn.id
#   display_name   = "my_vcn_route_table"

#   route_rules {
#     destination       = "0.0.0.0/0"
#     destination_type  = "CIDR_BLOCK"
#     network_entity_id = oci_core_internet_gateway.my_vcn_internet_gateway.id
#   }
# }

# resource "oci_core_security_list" "my_vcn_security_list" {
#   compartment_id = local.oracle_cloud_tenancy_id
#   vcn_id         = oci_core_vcn.my_vcn.id
#   display_name   = "my_vcn_security_list"

#   egress_security_rules {
#     protocol    = "6"
#     destination = "0.0.0.0/0"
#   }

#   ingress_security_rules {
#     protocol = "6"
#     source   = "0.0.0.0/0"

#     tcp_options {
#       max = "22"
#       min = "22"
#     }
#   }
# }
