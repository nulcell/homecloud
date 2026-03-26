output "domain_id" {
  description = "UUID of the CloudStack domain."
  value       = cloudstack_domain.this.id
}

output "domain_name" {
  description = "Name of the CloudStack domain."
  value       = cloudstack_domain.this.name
}
