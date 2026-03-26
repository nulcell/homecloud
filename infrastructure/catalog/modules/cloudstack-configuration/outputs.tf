output "applied_settings" {
  description = "Echo of all global_settings that were applied — keyed by configuration name."
  value       = { for k, v in var.global_settings : k => v }
}
