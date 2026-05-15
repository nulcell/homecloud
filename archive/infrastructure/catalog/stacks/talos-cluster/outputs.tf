output "cluster_endpoint" {
  description = "Kubernetes API server endpoint."
  value       = var.is_enabled ? "https://${cloudstack_ipaddress.lb[0].ip_address}:6443" : ""
}

output "lb_ip" {
  description = "Public IP address of the load balancer."
  value       = var.is_enabled ? cloudstack_ipaddress.lb[0].ip_address : ""
}

output "kubeconfig" {
  description = "Kubeconfig YAML for the cluster."
  value       = var.is_enabled ? module.bootstrap[0].kubeconfig : ""
  sensitive   = true
}

output "talosconfig" {
  description = "Talosconfig YAML for talosctl."
  value       = var.is_enabled ? module.talos_config[0].talosconfig : ""
  sensitive   = true
}

output "control_plane_vm_ids" {
  description = "UUIDs of control plane VMs."
  value       = var.is_enabled ? [for vm in module.control_plane_vms : vm.vm_id] : []
}

output "worker_vm_ids" {
  description = "UUIDs of worker VMs."
  value       = var.is_enabled ? [for vm in module.worker_vms : vm.vm_id] : []
}

output "argocd_server_url" {
  description = "ArgoCD server URL (only set when enable_argocd = true)."
  value       = var.is_enabled && var.enable_argocd ? "https://${cloudstack_ipaddress.lb[0].ip_address}" : ""
}
