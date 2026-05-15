output "network_id" {
  description = "UUID of the isolated network."
  value       = cloudstack_network.this.id
}

output "network_name" {
  description = "Name of the isolated network."
  value       = cloudstack_network.this.name
}

output "cidr" {
  description = "CIDR block of the isolated network."
  value       = cloudstack_network.this.cidr
}

output "gateway" {
  description = "Gateway IP of the isolated network."
  value       = cloudstack_network.this.gateway
}
