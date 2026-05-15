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
  tailscale_auth_key = var.op_tailscale_ref != "" ? local._ts_credential : try(module.tailscale_key[0].key, null)
}
