output "zone_id" {
  description = "UUID of the CloudStack zone."
  value       = module.zone.zone_id
}

output "domain_id" {
  description = "UUID of the CloudStack domain."
  value       = module.domain.domain_id
}

output "disk_offering_ids" {
  description = "Map of disk offering name → UUID."
  value       = module.offerings.disk_offering_ids
}

output "compute_offering_ids" {
  description = "Map of compute offering name → UUID."
  value       = module.offerings.compute_offering_ids
}

output "network_offering_ids" {
  description = "Map of network offering name → UUID."
  value       = module.offerings.network_offering_ids
}

output "vpc_offering_ids" {
  description = "Map of VPC offering name → UUID."
  value       = module.offerings.vpc_offering_ids
}

# Convenience shortcuts — use try() since offerings are created via null_resource and empty during plan
output "isolated_core_offering_id" {
  description = "UUID of the isolated.core-redundant network offering."
  value       = try(module.offerings.network_offering_ids["isolated.core-redundant"], null)
}

output "public_lb_offering_id" {
  description = "UUID of the vpc.core-public-lb network offering."
  value       = try(module.offerings.network_offering_ids["vpc.core-public-lb"], null)
}

output "internal_lb_offering_id" {
  description = "UUID of the vpc.core-internal-lb network offering."
  value       = try(module.offerings.network_offering_ids["vpc.core-internal-lb"], null)
}

output "vpc_offering_id" {
  description = "UUID of the natted.redundant-core VPC offering."
  value       = try(module.offerings.vpc_offering_ids["natted.redundant-core"], null)
}

output "template_ids" {
  description = "Map of all template keys → UUID."
  value       = module.templates.template_ids
}

output "ubuntu_template_id" {
  description = "UUID of the Ubuntu 24.04 template."
  value       = try(module.templates.template_ids["ubuntu-24.04"], null)
}

output "talos_template_id" {
  description = "UUID of the Talos v1.12.6 template."
  value       = try(module.templates.template_ids["talos-v1.12.6"], null)
}
