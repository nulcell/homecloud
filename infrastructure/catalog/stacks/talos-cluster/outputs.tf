output "cluster_endpoint" {
  description = "Kubernetes API server endpoint."
  value       = "https://${cloudstack_ipaddress.lb.ip_address}:6443"
}

output "lb_ip" {
  description = "Public IP address of the load balancer."
  value       = cloudstack_ipaddress.lb.ip_address
}

output "kubeconfig" {
  description = "Kubeconfig YAML for the cluster."
  value       = module.bootstrap.kubeconfig
  sensitive   = true
}

output "talosconfig" {
  description = "Talosconfig YAML for talosctl."
  value       = module.talos_config.talosconfig
  sensitive   = true
}

output "control_plane_vm_ids" {
  description = "UUIDs of control plane VMs."
  value       = [for vm in module.control_plane_vms : vm.vm_id]
}

output "worker_vm_ids" {
  description = "UUIDs of worker VMs."
  value       = [for vm in module.worker_vms : vm.vm_id]
}

output "argocd_server_url" {
  description = "ArgoCD server URL (only set when enable_argocd = true)."
  value       = var.enable_argocd ? "https://${cloudstack_ipaddress.lb.ip_address}" : ""
}
