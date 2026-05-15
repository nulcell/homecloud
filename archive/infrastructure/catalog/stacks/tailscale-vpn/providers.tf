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
  account = var.op_account
}
