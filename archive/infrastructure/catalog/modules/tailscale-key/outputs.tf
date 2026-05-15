output "key" {
  description = "The Tailscale auth key value."
  value       = tailscale_tailnet_key.this.key
  sensitive   = true
}
