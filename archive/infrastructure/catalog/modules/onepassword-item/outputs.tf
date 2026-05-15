output "item" {
  description = "The full 1Password item object (resource in write mode, data source in read mode)."
  value       = length(var.fields) > 0 ? onepassword_item.this[0] : data.onepassword_item.this[0]
  sensitive   = true
}

output "fields" {
  description = "Map of section label → field label → value from the 1Password item."
  value       = length(var.fields) > 0 ? null : data.onepassword_item.this[0].section_map
  sensitive   = true
}
