output "userdata_ids" {
  description = "Map of userdata name → CloudStack UUID."
  value       = { for k, v in cloudstack_user_data.this : k => v.id }
}
