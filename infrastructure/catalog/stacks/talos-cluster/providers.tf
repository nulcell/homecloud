# ---------------------------------------------------------------------------
# 1Password data sources
# ---------------------------------------------------------------------------

data "onepassword_item" "cs_homecloud" {
  vault = var.op_vault
  title = "CloudStack - homecloud-admin"
}

# ---------------------------------------------------------------------------
# Locals — field lookups
# ---------------------------------------------------------------------------
locals {
  _cs_all_fields = flatten([for s in data.onepassword_item.cs_homecloud.section : s.field])
  cs_api_key     = one([for f in local._cs_all_fields : f.value if f.label == "api key"])
  cs_secret_key  = one([for f in local._cs_all_fields : f.value if f.label == "secret key"])
}

# ---------------------------------------------------------------------------
# Providers
# ---------------------------------------------------------------------------

provider "cloudstack" {
  api_url    = var.cloudstack_api_url
  api_key    = local.cs_api_key
  secret_key = local.cs_secret_key
}

provider "talos" {}

provider "onepassword" {
  # Authenticates via OP_SERVICE_ACCOUNT_TOKEN or an active op CLI session.
}
