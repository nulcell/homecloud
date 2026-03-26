# ---------------------------------------------------------------------------
# 1Password data sources
# ---------------------------------------------------------------------------

data "onepassword_item" "cs_homecloud" {
  vault = var.op_vault
  title = "CloudStack - homecloud-admin"
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
  # CloudStack API credentials (stored in a sectioned Secure Note)
  _cs_all_fields = flatten([for s in data.onepassword_item.cs_homecloud.section : s.field])
  cs_api_key     = one([for f in local._cs_all_fields : f.value if f.label == "api key"])
  cs_secret_key  = one([for f in local._cs_all_fields : f.value if f.label == "secret key"])

  # Tailscale auth key: prefer 1Password item; fall back to generated key
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
  # Authenticates via TAILSCALE_API_KEY environment variable.
  # Only used when op_tailscale_ref = "" (generating a new key).
}

provider "onepassword" {
  # Authenticates via OP_SERVICE_ACCOUNT_TOKEN or an active op CLI session.
}
