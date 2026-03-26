# ── Zone ──────────────────────────────────────────────────────────────────────

output "zone_id" {
  description = "UUID of the CloudStack zone."
  value       = module.zone.zone_id
}

# ── Domain ────────────────────────────────────────────────────────────────────

output "domain_id" {
  description = "UUID of the CloudStack domain."
  value       = module.domain.domain_id
}

# ── Offerings ─────────────────────────────────────────────────────────────────

output "disk_offering_ids" {
  description = "Map of disk offering name → UUID."
  value       = module.offerings.disk_offering_ids
}

output "compute_offering_ids" {
  description = "Map of compute offering name → UUID."
  value       = module.offerings.compute_offering_ids
}

output "network_offering_ids" {
  description = "Map of network offering name → UUID. Consumed by cloudstack-homecloud."
  value       = module.offerings.network_offering_ids
}

output "vpc_offering_ids" {
  description = "Map of VPC offering name → UUID. Consumed by cloudstack-homecloud."
  value       = module.offerings.vpc_offering_ids
}

# ── Convenience shortcuts (consumed by cloudstack-homecloud) ─────────────────

output "isolated_core_offering_id" {
  description = "UUID of the isolated.core-redundant network offering."
  value       = module.offerings.network_offering_ids["isolated.core-redundant"]
}

output "public_lb_offering_id" {
  description = "UUID of the vpc.core-public-lb network offering."
  value       = module.offerings.network_offering_ids["vpc.core-public-lb"]
}

output "internal_lb_offering_id" {
  description = "UUID of the vpc.core-internal-lb network offering."
  value       = module.offerings.network_offering_ids["vpc.core-internal-lb"]
}

output "vpc_offering_id" {
  description = "UUID of the natted.redundant-core VPC offering."
  value       = module.offerings.vpc_offering_ids["natted.redundant-core"]
}

# ── Templates ─────────────────────────────────────────────────────────────────

output "template_ids" {
  description = "Map of template key → UUID."
  value       = module.templates.template_ids
}

output "ubuntu_template_id" {
  description = "UUID of the Ubuntu 24.04 template."
  value       = module.templates.template_ids["ubuntu-24.04"]
}

output "talos_template_id" {
  description = "UUID of the Talos v1.12.6 template."
  value       = module.templates.template_ids["talos-v1.12.6"]
}
