output "item" {
  description = "The full 1Password item data source object."
  value       = data.onepassword_item.this
  sensitive   = true
}

output "fields" {
  description = "All fields from the 1Password item."
  value       = data.onepassword_item.this.fields
  sensitive   = true
}
