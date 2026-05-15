output "filesystem_names" {
  description = "List of filesystem names managed by this module. UUIDs are not tracked in state (null_resource limitation)."
  value       = keys(var.filesystems)
}
