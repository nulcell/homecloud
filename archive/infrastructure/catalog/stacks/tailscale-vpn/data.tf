data "onepassword_item" "cs_homecloud" {
  vault = var.op_vault
  title = "CloudStack - homecloud-admin"
}

# Tailscale account credentials — used to configure the tailscale provider
# and to generate the subnet router auth key.
data "onepassword_item" "tailscale" {
  vault = var.op_vault
  title = "Tailscale"
}

# Read an existing Tailscale auth key from 1Password when op_tailscale_ref is set
data "onepassword_item" "tailscale_token" {
  count = var.op_tailscale_ref != "" ? 1 : 0
  vault = var.op_vault
  title = var.op_tailscale_ref
}
