resource "tailscale_tailnet_key" "this" {
  description = var.description
  reusable    = var.reusable
  ephemeral   = var.ephemeral
  tags        = var.tags
  expiry      = var.expiry_seconds
}
