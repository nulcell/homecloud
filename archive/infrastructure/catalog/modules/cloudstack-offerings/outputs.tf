output "disk_offering_ids" {
  description = "Map of disk offering name → UUID (fixed-size offerings only)."
  value       = { for k, v in cloudstack_disk_offering.fixed : k => v.id }
}

output "compute_offering_ids" {
  description = "Map of all compute offering names → UUID across all three offering types."
  value = merge(
    { for k, v in cloudstack_service_offering_fixed.this : k => v.id },
    { for k, v in cloudstack_service_offering_unconstrained.this : k => v.id },
    { for k, v in cloudstack_service_offering_constrained.this : k => v.id },
  )
}

output "network_offering_ids" {
  description = "Map of network offering name → UUID."
  value       = { for k, v in cloudstack_network_offering.network : k => v.id }
}

output "vpc_offering_ids" {
  description = "Map of VPC offering name → UUID. These are created via CloudMonkey (no native TF resource); pass existing UUIDs via existing_vpc_offering_ids."
  value       = var.existing_vpc_offering_ids
}
