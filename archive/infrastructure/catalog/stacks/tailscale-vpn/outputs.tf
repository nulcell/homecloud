output "router_vm_id" {
  description = "UUID of the VPN router VM. Empty when is_enabled = false."
  value       = module.router_vm.vm_id
}

output "router_vm_ip" {
  description = "Primary private IP of the VPN router VM. Empty when is_enabled = false."
  value       = module.router_vm.private_ip
}
