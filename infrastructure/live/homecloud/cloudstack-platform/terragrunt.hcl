# cloudstack-platform unit
# Deploys the full CloudStack platform component:
#   - Domain + Account + resource limits
#   - Zone configuration + global settings
#   - Compute, disk, network, and VPC offerings
#   - Templates (Ubuntu, Talos ISO)
#   - VPC + pub/priv subnets
#   - Isolated network (iso-net-shared)
#   - SSH keypair
#   - User-data scripts (tailscale-router cloud-init)

include "root" {
  path = find_in_parent_folders("root.hcl")
}

include "account" {
  path   = find_in_parent_folders("account.hcl")
  expose = true
}

terraform {
  source = "${get_repo_root()}//infrastructure/catalog/stacks/cloudstack-platform"
}

inputs = {
  # ── CloudStack connection ────────────────────────────────────────────────
  cloudstack_api_url = include.account.locals.cloudstack_api_url
  op_vault           = include.account.locals.op_vault

  # ── Domain / Account ────────────────────────────────────────────────────
  domain_name    = "homecloud"
  domain_network = include.account.locals.network_domain
  account_name   = "homecloud"
  timezone       = "Europe/Amsterdam"

  # ── Zone ────────────────────────────────────────────────────────────────
  zone_name = include.account.locals.zone_name

  # ── VPC / Networks ──────────────────────────────────────────────────────
  vpc_name        = "vpc-homecloud"
  vpc_cidr        = include.account.locals.vpc_cidr
  isolated_net_name = "iso-net-shared"
  isolated_net_cidr = include.account.locals.isolated_net_cidr

  # ── Subnets inside the VPC ───────────────────────────────────────────────
  subnets = {
    "pub-net-1"  = { cidr = "10.0.0.0/26",  gateway = "10.0.0.1",   vlan = 200 }
    "priv-net-1" = { cidr = "10.0.0.64/26", gateway = "10.0.0.65",  vlan = 201 }
    "priv-net-2" = { cidr = "10.0.0.128/26",gateway = "10.0.0.129", vlan = 202 }
    "priv-net-3" = { cidr = "10.0.0.192/26",gateway = "10.0.0.193", vlan = 203 }
  }

  # ── SSH keypair ──────────────────────────────────────────────────────────
  keypair_name     = "homecloud-key"
  op_keypair_ref   = "op://homecloud/SSH - homecloud/public key"
}
