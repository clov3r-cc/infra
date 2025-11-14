output "prd__zabbix_servers" {
  value = module.prd__zabbix_servers.zabbix_servers
}

# TODO: Fix me
# output "prod__k8s_gateway_node" {
#   value = module.prod__k8s_nodes.gateway
# }

# output "prod__k8s_worker_nodes" {
#   value = module.prod__k8s_nodes.worker_nodes
# }

# output "prod__k8s_control_plane_nodes" {
#   value = module.prod__k8s_nodes.control_plane_nodes
# }
