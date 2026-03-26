output "vpc_id" {
  description = "UUID of the homecloud VPC."
  value       = module.vpc.vpc_id
}

output "network_ids" {
  description = "Map of VPC network tier key → UUID."
  value       = module.vpc.network_ids
}

output "pub_net_1_id" {
  description = "UUID of the pub-net-1 VPC network tier."
  value       = module.vpc.pub_net_1_id
}

output "priv_net_1_id" {
  description = "UUID of the priv-net-1 VPC network tier."
  value       = module.vpc.priv_net_1_id
}

output "priv_net_2_id" {
  description = "UUID of the priv-net-2 VPC network tier."
  value       = module.vpc.priv_net_2_id
}

output "priv_net_3_id" {
  description = "UUID of the priv-net-3 VPC network tier."
  value       = module.vpc.priv_net_3_id
}

output "iso_net_id" {
  description = "UUID of the iso-net-shared isolated network."
  value       = module.isolated_network.network_id
}

output "keypair_name" {
  description = "Name of the registered SSH keypair."
  value       = var.keypair_name
}

output "userdata_ids" {
  description = "Map of userdata name → empty string (UUIDs not tracked in state; query CloudStack directly)."
  value       = module.userdata.userdata_ids
}

output "vps_id" {
  description = "UUID of the VPS VM. Empty string when enable_vps = false."
  value       = var.enable_vps ? module.vps[0].vm_id : ""
}

output "vps_ip" {
  description = "Primary private IP of the VPS VM. Empty string when enable_vps = false."
  value       = var.enable_vps ? module.vps[0].private_ip : ""
}
