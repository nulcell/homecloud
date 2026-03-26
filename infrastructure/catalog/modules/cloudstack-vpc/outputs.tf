output "vpc_id" {
  description = "UUID of the VPC."
  value       = cloudstack_vpc.this.id
}

output "network_ids" {
  description = "Map of network tier key → network UUID."
  value       = { for k, v in cloudstack_network.tiers : k => v.id }
}

output "pub_net_1_id" {
  description = "UUID of the pub-net-1 VPC network tier."
  value       = cloudstack_network.tiers["pub-net-1"].id
}

output "priv_net_1_id" {
  description = "UUID of the priv-net-1 VPC network tier."
  value       = cloudstack_network.tiers["priv-net-1"].id
}

output "priv_net_2_id" {
  description = "UUID of the priv-net-2 VPC network tier."
  value       = cloudstack_network.tiers["priv-net-2"].id
}

output "priv_net_3_id" {
  description = "UUID of the priv-net-3 VPC network tier."
  value       = cloudstack_network.tiers["priv-net-3"].id
}
