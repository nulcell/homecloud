output "zone_id" {
  description = "UUID of the CloudStack zone."
  value       = cloudstack_zone.this.id
}

output "zone_name" {
  description = "Name of the CloudStack zone."
  value       = cloudstack_zone.this.name
}

output "pod_id" {
  description = "UUID of the CloudStack pod."
  value       = cloudstack_pod.this.id
}

output "cluster_id" {
  description = "UUID of the KVM cluster."
  value       = cloudstack_cluster.this.id
}

output "physical_network_ids" {
  description = "Map of physical network name → UUID."
  value       = { for k, v in cloudstack_physical_network.this : k => v.id }
}

output "primary_storage_pool_ids" {
  description = "Map of primary storage pool name → UUID."
  value       = { for k, v in cloudstack_storage_pool.primary : k => v.id }
}

output "secondary_storage_ids" {
  description = "Map of secondary storage (image store) name → UUID."
  value       = { for k, v in cloudstack_secondary_storage.this : k => v.id }
}
