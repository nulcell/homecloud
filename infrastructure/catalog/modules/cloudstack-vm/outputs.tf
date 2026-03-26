output "vm_id" {
  description = "UUID of the deployed VM instance. Empty string when enable = false."
  value       = var.enable ? cloudstack_instance.this[0].id : ""
}

output "vm_name" {
  description = "Name of the VM instance."
  value       = var.name
}

output "private_ip" {
  description = "Primary private IP address of the VM. Empty string when enable = false."
  value       = var.enable ? cloudstack_instance.this[0].ip_address : ""
}
