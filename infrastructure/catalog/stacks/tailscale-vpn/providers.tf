# ---------------------------------------------------------------------------
# 1Password data sources
# ---------------------------------------------------------------------------

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

# ---------------------------------------------------------------------------
# Locals — field lookups
# ---------------------------------------------------------------------------
locals {
  # CloudStack API credentials — consistent merge pattern across all stacks.
  _cs_fields    = merge([for s in data.onepassword_item.cs_homecloud.section : { for f in s.field : f.label => f.value }]...)
  cs_api_key    = local._cs_fields["api-key"]
  cs_secret_key = local._cs_fields["secret-key"]

  # Tailscale API token — stored in 1Password under Tailscale > API > api-token.
  _ts_fields        = merge([for s in data.onepassword_item.tailscale.section : { for f in s.field : f.label => f.value }]...)
  tailscale_api_key = local._ts_fields["api-token"]

  # Tailscale auth key: prefer 1Password item; fall back to generated key.
  _ts_credential     = var.op_tailscale_ref != "" ? data.onepassword_item.tailscale_token[0].password : null
  tailscale_auth_key = var.op_tailscale_ref != "" ? local._ts_credential : module.tailscale_key[0].key
}

# ---------------------------------------------------------------------------
# Providers
# ---------------------------------------------------------------------------

provider "cloudstack" {
  api_url    = var.cloudstack_api_url
  api_key    = local.cs_api_key
  secret_key = local.cs_secret_key
}

provider "tailscale" {
  # API token read from 1Password — used for managing tailnet keys.
  api_key = local.tailscale_api_key
}

provider "onepassword" {
  # Authenticates via OP_SERVICE_ACCOUNT_TOKEN or an active op CLI session.
}
