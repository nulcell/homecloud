# ---------------------------------------------------------------------------
# 1Password data sources
# ---------------------------------------------------------------------------

# CloudStack homecloud-admin API credentials
data "onepassword_item" "cs_homecloud" {
  vault = var.op_vault
  title = var.op_cs_homecloud_item
}

# SSH public key for keypair registration (SSH Key item type in 1Password)
data "onepassword_item" "nulcell_key" {
  vault = var.op_vault
  title = "nulcell"
}

# ---------------------------------------------------------------------------
# Locals — field lookups from 1Password items
# ---------------------------------------------------------------------------
locals {
  # Flatten all section fields to find CloudStack API credentials by label.
  _cs_all_fields    = flatten([for s in data.onepassword_item.cs_homecloud.section : s.field])
  cs_api_key        = one([for f in local._cs_all_fields : f.value if f.label == "api key"])
  cs_secret_key     = one([for f in local._cs_all_fields : f.value if f.label == "secret key"])

  # For 1Password SSH Key item types, public_key is a first-class attribute.
  # If the nulcell item is a generic Login/Secure Note with a custom field,
  # change this to use section field lookup (same pattern as cs_api_key above).
  nulcell_public_key = data.onepassword_item.nulcell_key.public_key
}

# ---------------------------------------------------------------------------
# Providers
# ---------------------------------------------------------------------------

provider "cloudstack" {
  api_url    = var.cloudstack_api_url
  api_key    = local.cs_api_key
  secret_key = local.cs_secret_key
}

provider "onepassword" {
  # Authenticates via OP_SERVICE_ACCOUNT_TOKEN environment variable or an
  # active `op` CLI session.  No static credentials are stored here.
}
