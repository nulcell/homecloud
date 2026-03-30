# cloudstack-homecloud unit
# homecloud domain-scope resources (cloudstack.homecloud provider ONLY).
# Depends on cloudstack-admin (domain + account + offerings must exist first).
#
# Optionality convention:
#   - for_each map inputs: empty map = nothing created; remove entry = resource deleted
#   - Single optional resources: `enable_X = false` → not created; set true → created/managed
#   - Images/templates in cloudstack-admin: lifecycle prevent_destroy (never auto-deleted)
#   - VMs: can be safely deleted when disabled; data is on NFS/external storage
#
# Manages:
#   - VPC (homecloud-vpc, 10.0.0.0/24) + 4 network tiers      (IMPORTED)
#   - Isolated network (iso-net-shared, 10.1.1.0/24)           (IMPORTED)
#   - SSH keypair (nulcell) — domain-scoped to homecloud        (IMPORTED, optional)
#   - User-data scripts — for_each map (empty = none)           (REGISTERED)
#   - NFS SharedFileSystems — for_each map (empty = none)       (CREATED/IMPORTED, optional)
#   - General-purpose VPS VM (homecloud-vps)                    (CREATED, optional)
#   - Generates homecloud-admin CloudStack API key → 1Password

include "root" {
  path = find_in_parent_folders("root.hcl")
}

include "account" {
  path   = find_in_parent_folders("account.hcl")
  expose = true
}

terraform {
  source = "${get_repo_root()}//infrastructure/catalog/stacks/cloudstack-homecloud"
}

dependency "cloudstack_admin" {
  config_path = "../cloudstack-admin"

  mock_outputs = {
    domain_id         = "mock-domain-id"
    disk_offering_ids = { "shared.custom" = "mock-id" }
  }
  mock_outputs_allowed_terraform_commands = ["validate", "plan"]
}

inputs = {
  cloudstack_api_url = include.account.locals.cloudstack_api_url
  op_vault           = include.account.locals.op_vault
  op_account         = include.account.locals.op_account
  zone_name          = include.account.locals.zone_name
  domain_id          = dependency.cloudstack_admin.outputs.domain_id
  domain_name        = "homecloud"
  account_name       = "homecloud"

  disk_offering_ids = dependency.cloudstack_admin.outputs.disk_offering_ids

  # ── Existing resource import IDs ─────────────────────────────────────────
  existing_vpc_id          = "7c508ae5-0d94-4956-a648-c714796d966a"
  existing_network_ids = {
    "pub-net-1"  = "a0e592ee-0367-4217-9b07-ab3069ed312a"
    "priv-net-1" = "03f0e6d4-2aa1-4fc5-87fb-5978b6a9496e"
    "priv-net-2" = "b7e04452-49ed-4756-841e-46fac7ebe942"
    "priv-net-3" = "fc919529-8f7d-46a3-ae5a-a06c0f562f49"
  }
  existing_isolated_net_id = "96796c3f-84f8-46aa-99fc-0904e4054509"
  existing_keypair_id      = "06f891df-e322-4b5c-af4f-003d965e6e8f"
  existing_vps_id          = "47827b6e-1e96-4c45-be96-d1457ed6cd0b"
  existing_userdata_ids    = {}

  # Default ACL for VPC networks (default_allow list)
  default_acl_id = "1299e2f2-e8a9-11f0-a9d5-b0416f175a55"

  # ── VPC ───────────────────────────────────────────────────────────────────
  vpc_name          = "homecloud-vpc"
  vpc_cidr          = include.account.locals.vpc_cidr
  vpc_offering_name = "acs.vpc.natted.redundant-core"

  # ── VPC Network Tiers ────────────────────────────────────────────────────
  # pub-net-1 uses vpc.core-public-lb offering (CloudStack LB rule target)
  # priv-net-1/2/3 use vpc.core-internal-lb offering
  vpc_networks = {
    "pub-net-1"  = { cidr = "10.0.0.0/26",   gateway = "10.0.0.1",   offering_name = "vpc.core-public-lb" }
    "priv-net-1" = { cidr = "10.0.0.64/26",  gateway = "10.0.0.65",  offering_name = "vpc.core-internal-lb" }
    "priv-net-2" = { cidr = "10.0.0.128/26", gateway = "10.0.0.129", offering_name = "vpc.core-internal-lb" }
    "priv-net-3" = { cidr = "10.0.0.192/26", gateway = "10.0.0.193", offering_name = "vpc.core-internal-lb" }
  }

  # ── Isolated Network ────────────────────────────────────────────────────
  # Used by the ops Talos cluster. Separate from the VPC to work around the
  # CloudStack limitation of only one public-LB subnet per VPC.
  isolated_net_name         = "iso-net-shared"
  isolated_net_cidr         = include.account.locals.isolated_net_cidr
  isolated_net_gateway      = "10.1.1.1"
  isolated_net_offering_name = "isolated.core-redundant"

  # ── SSH Keypair (optional — omit keypair_name to skip) ──────────────────
  keypair_name   = "nulcell"
  op_ssh_pub_key = "op://homecloud/nulcell/public key"

  # ── User Data Scripts (for_each map — empty map = nothing registered) ────
  userdata_scripts = {
    "cloud-default" = {
      file   = "${get_repo_root()}/cloudstack/compute/cloud-init/cloud-default.yaml"
      params = []
    }
    "tailscale-router-debian" = {
      file   = "${get_repo_root()}/cloudstack/compute/cloud-init/tailscale-router-debian.yaml"
      params = ["tailscale_auth_key", "network_router_cidr"]
    }
  }

  # ── NFS Shared Filesystems (for_each map — empty map = none created) ─────
  # Remove an entry to delete that filesystem (data loss — do deliberately).
  # Use enable_shared_storage = false to disable ALL without removing entries.
  enable_shared_storage = true
  shared_filesystems = {
    "media-server-fs-config" = {
      size_gb          = 10
      service_offering = "gen.medium.fixed"
      disk_offering    = "shared.custom"
      network_name     = "pub-net-1"
    }
    "media-server-fs-data" = {
      size_gb          = 500
      service_offering = "gen.medium.fixed"
      disk_offering    = "shared.custom"
      network_name     = "pub-net-1"
    }
  }

  # ── General-Purpose VPS VM (optional) ────────────────────────────────────
  # Ubuntu 24.04 VM on priv-net-1, general workloads, cloud-default userdata.
  # Set enable_vps = false to skip creation without removing the config.
  enable_vps = true
  vps = {
    name             = "homecloud-vps"
    compute_offering = "gen.xlarge"
    root_disk_size   = 30
    network_name     = "priv-net-1"
    userdata_name    = "cloud-default"
  }

  # ── 1Password: write generated API key here ──────────────────────────────
  op_cs_homecloud_item = "CloudStack - homecloud-admin"
}
