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

  # Default ACL for VPC networks (default_allow list)
  default_acl_id = "1299e2f2-e8a9-11f0-a9d5-b0416f175a55"

  vpc_name          = "homecloud-vpc"
  vpc_cidr          = include.account.locals.vpc_cidr
  vpc_offering_name = "acs.vpc.natted.redundant-core"

  # pub-net-1 uses vpc.core-public-lb offering (CloudStack LB rule target)
  # priv-net-1/2/3 use vpc.core-internal-lb offering
  vpc_networks = {
    "pub-net-1"  = { cidr = "10.0.0.0/26",   gateway = "10.0.0.1",   offering_name = "vpc.core-public-lb" }
    "priv-net-1" = { cidr = "10.0.0.64/26",  gateway = "10.0.0.65",  offering_name = "vpc.core-internal-lb" }
    "priv-net-2" = { cidr = "10.0.0.128/26", gateway = "10.0.0.129", offering_name = "vpc.core-internal-lb" }
    "priv-net-3" = { cidr = "10.0.0.192/26", gateway = "10.0.0.193", offering_name = "vpc.core-internal-lb" }
  }

  # Used by the ops Talos cluster. Separate from the VPC to work around the
  # CloudStack limitation of only one public-LB subnet per VPC.
  isolated_net_name         = "iso-net-shared"
  isolated_net_cidr         = include.account.locals.isolated_net_cidr
  isolated_net_gateway      = "10.1.1.1"
  isolated_net_offering_name = "isolated.core-redundant"

  keypair_name   = "nulcell"
  enable_keypair = false
  op_ssh_pub_key = "op://homecloud/nulcell/public key"

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

  # Remove an entry to delete that filesystem (data loss — do deliberately).
  # Use enable_shared_storage = false to disable ALL without removing entries.
  enable_shared_storage = true
  shared_filesystems = {
    "media-server-fs-config" = {
      size_gb          = 10
      service_offering = "gen.medium.fixed"
      disk_offering    = "shared.custom"
      network_name     = "homecloud-vpc_pub-net-1"
    }
    "media-server-fs-data" = {
      size_gb          = 500
      service_offering = "gen.medium.fixed"
      disk_offering    = "shared.custom"
      network_name     = "homecloud-vpc_pub-net-1"
    }
  }

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

  op_cs_homecloud_item = "CloudStack - homecloud-admin"
}
