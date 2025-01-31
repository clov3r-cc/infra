output "k8s_gateway_node__prod" {
  value = module.k8s_nodes__prod.gateway
}

output "k8s_worker_nodes__prod" {
  value = module.k8s_nodes__prod.worker_nodes
}

output "k8s_control_plane_nodes__prod" {
  value = module.k8s_nodes__prod.control_plane_nodes
}
