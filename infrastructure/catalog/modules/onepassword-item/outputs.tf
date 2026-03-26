output "item" {
  description = "The full 1Password item data source object."
  value       = data.onepassword_item.this
  sensitive   = true
}

output "fields" {
  description = "Map of section label → field label → value from the 1Password item."
  value       = data.onepassword_item.this.section_map
  sensitive   = true
}
