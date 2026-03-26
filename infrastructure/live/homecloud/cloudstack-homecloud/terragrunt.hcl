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
    zone_id                    = "mock-zone-id"
    domain_id                  = "mock-domain-id"
    vpc_offering_id            = "mock-vpc-offering-id"
    public_lb_offering_id      = "mock-net-offering-id"
    internal_lb_offering_id    = "mock-net-offering-id"
    isolated_core_offering_id  = "mock-net-offering-id"
    ubuntu_template_id         = "mock-template-id"
    talos_template_id          = "mock-template-id"
    compute_offering_ids       = { "gen.tiny" = "mock-id", "mem.medium" = "mock-id", "gen.1xlarge" = "mock-id" }
    disk_offering_ids          = { "shared.custom" = "mock-id" }
  }
  mock_outputs_allowed_terraform_commands = ["validate", "plan"]
}

inputs = {
  cloudstack_api_url = include.account.locals.cloudstack_api_url
  op_vault           = include.account.locals.op_vault
  zone_id            = dependency.cloudstack_admin.outputs.zone_id
  domain_id          = dependency.cloudstack_admin.outputs.domain_id
  account_name       = "homecloud"

  # Pass-through: offering/template IDs from admin that downstream units (tailscale-vpn,
  # ops-cluster, workload-cluster) need. The cloudstack-homecloud stack outputs these as-is.
  ubuntu_template_id   = dependency.cloudstack_admin.outputs.ubuntu_template_id
  talos_template_id    = dependency.cloudstack_admin.outputs.talos_template_id
  compute_offering_ids = dependency.cloudstack_admin.outputs.compute_offering_ids
  disk_offering_ids    = dependency.cloudstack_admin.outputs.disk_offering_ids

  # ── VPC ───────────────────────────────────────────────────────────────────
  vpc_name          = "homecloud-vpc"
  vpc_cidr          = include.account.locals.vpc_cidr
  vpc_offering_id   = dependency.cloudstack_admin.outputs.vpc_offering_id

  # ── VPC Network Tiers ────────────────────────────────────────────────────
  # pub-net-1 uses vpc.core-public-lb offering (CloudStack LB rule target)
  # priv-net-1/2/3 use vpc.core-internal-lb offering
  vpc_networks = {
    "pub-net-1"  = { cidr = "10.0.0.0/26",   gateway = "10.0.0.1",   offering_id = dependency.cloudstack_admin.outputs.public_lb_offering_id }
    "priv-net-1" = { cidr = "10.0.0.64/26",  gateway = "10.0.0.65",  offering_id = dependency.cloudstack_admin.outputs.internal_lb_offering_id }
    "priv-net-2" = { cidr = "10.0.0.128/26", gateway = "10.0.0.129", offering_id = dependency.cloudstack_admin.outputs.internal_lb_offering_id }
    "priv-net-3" = { cidr = "10.0.0.192/26", gateway = "10.0.0.193", offering_id = dependency.cloudstack_admin.outputs.internal_lb_offering_id }
  }

  # ── Isolated Network ────────────────────────────────────────────────────
  # Used by the ops Talos cluster. Separate from the VPC to work around the
  # CloudStack limitation of only one public-LB subnet per VPC.
  isolated_net_name       = "iso-net-shared"
  isolated_net_cidr       = include.account.locals.isolated_net_cidr
  isolated_net_gateway    = "10.1.1.1"
  isolated_net_offering_id = dependency.cloudstack_admin.outputs.isolated_core_offering_id

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
    template_name    = "Ubuntu 24.04 - Noble"
  }

  # ── 1Password: write generated API key here ──────────────────────────────
  op_cs_homecloud_item = "CloudStack - homecloud-admin"
}
