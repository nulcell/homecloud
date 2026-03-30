output "template_ids" {
  description = "Map of template key → UUID for templates registered via cloudstack_template resource."
  value       = { for k, v in cloudstack_template.this : k => v.id }
}

output "iso_ids" {
  # ISOs are managed by null_resource (cmk CLI). CloudStack UUIDs are not
  # tracked in Terraform state. Use `cmk list isos` to look up IDs.
  description = "ISO IDs are not tracked in Terraform state (null_resource). Use cmk list isos to retrieve UUIDs."
  value       = {}
}
