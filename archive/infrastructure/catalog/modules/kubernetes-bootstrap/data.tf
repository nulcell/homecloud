data "talos_cluster_health" "this" {
  client_configuration = var.client_configuration
  control_plane_nodes  = var.controlplane_ips
  worker_nodes         = var.worker_ips
  endpoints            = [var.talos_endpoint]

  depends_on = [talos_machine_bootstrap.this]

  timeouts = { read = "15m" }
}
