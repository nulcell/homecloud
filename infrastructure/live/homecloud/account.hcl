# account.hcl — homecloud account/environment configuration
# Picked up automatically by root.hcl via find_in_parent_folders("account.hcl").

locals {
  environment = "homecloud"
  stack_name  = "homecloud"

  # ─── CloudStack ───────────────────────────────────────────────────────────
  cloudstack_api_url = "http://cloudstack.nulcell.com:8080/client/api"

  # 1Password vault where homecloud secrets live
  op_vault = "homecloud"

  # CloudStack admin credentials (read from 1Password at plan/apply time)
  # Consumed by cloudstack.admin provider alias in each unit that needs it.
  op_cloudstack_admin_ref = {
    url      = "op://homecloud/CloudStack - admin/url"
    api_key  = "op://homecloud/CloudStack - admin/api key"
    secret   = "op://homecloud/CloudStack - admin/secret key"
  }

  # CloudStack homecloud-admin credentials (domain user)
  op_cloudstack_homecloud_ref = {
    api_key = "op://homecloud/CloudStack - homecloud-admin/api key"
    secret  = "op://homecloud/CloudStack - homecloud-admin/secret key"
  }

  # Tailscale tailnet name (set once; all units share it)
  tailscale_tailnet = "nulcell.com"

  # ─── Zone / Network ───────────────────────────────────────────────────────
  zone_name           = "zone-homecloud"
  network_domain      = "homecloud.internal"
  vpc_cidr            = "10.0.0.0/24"
  isolated_net_cidr   = "10.1.1.0/24"
  cloudflare_zone     = "nulcell.com" # update if different

  # ─── Cluster sizing (can be overridden per unit) ──────────────────────────
  ops_cluster_name      = "ops"
  workload_cluster_name = "workload"
}
