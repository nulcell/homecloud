# cloudstack-platform unit
# Deploys the full CloudStack platform component:
#   - Domain + Account + resource limits
#   - Zone configuration + global settings  (admin scope)
#   - Compute, disk, network, and VPC offerings
#   - Cloud images: Ubuntu 24.04, Talos ISO (with Tailscale extension)
#   - VPC + pub/priv subnets
#   - Isolated network (iso-net-shared)
#   - SSH keypair
#   - User-data scripts (tailscale-router cloud-init)
#   - SharedFileSystems (NFS, optional: enable_shared_storage)
#
# PROVIDER SCOPE:
#   This unit is the ONLY one that runs with CloudStack admin credentials.
#   Resources created under the homecloud domain use the cloudstack.homecloud alias.
#   All other live units use the homecloud-admin domain user credentials only.

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

  # ── Cloud Images ─────────────────────────────────────────────────────────
  # Provide the Talos Image Factory URL with the siderolabs/tailscale extension.
  # Build at: https://factory.talos.dev — enable siderolabs/tailscale extension.
  talos_iso_url       = "https://factory.talos.dev/image/<schematic-id>/v1.12.6/nocloud-amd64.iso" # replace <schematic-id>
  talos_iso_version   = "v1.12.6"
  ubuntu_image_url    = "https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img"
  ubuntu_image_version = "24.04"

  # ── Shared Storage (optional NFS volumes used by ArgoCD workloads) ───────
  enable_shared_storage  = true
  fs_config_name         = "media-server-fs-config"
  fs_config_size_gb      = 10
  fs_data_name           = "media-server-fs-data"
  fs_data_size_gb        = 500
}
