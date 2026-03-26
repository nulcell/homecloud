resource "tailscale_tailnet_key" "this" {
  description    = var.description
  reusable       = var.reusable
  ephemeral      = var.ephemeral
  tags           = var.tags
  expiry_seconds = var.expiry_seconds
}
