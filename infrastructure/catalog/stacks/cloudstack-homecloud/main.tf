# ---------------------------------------------------------------------------
# Import blocks for existing CloudStack resources
#
# Terraform 1.14 only allows import blocks in the root module. All import
# configuration is centralised here; set existing_* variables in your
# terragrunt.hcl inputs to import pre-existing resources.
# ---------------------------------------------------------------------------

# VPC
import {
  for_each = var.existing_vpc_id != "" ? { this = var.existing_vpc_id } : {}
  to       = module.vpc.cloudstack_vpc.this
  id       = each.value
}

# VPC network tiers
import {
  for_each = { for k, v in var.existing_network_ids : k => v if v != "" }
  to       = module.vpc.cloudstack_network.tiers[each.key]
  id       = each.value
}

# Isolated network
import {
  for_each = var.existing_isolated_net_id != "" ? { this = var.existing_isolated_net_id } : {}
  to       = module.isolated_network.cloudstack_network.this
  id       = each.value
}

# SSH keypair
# NOTE: cloudstack_ssh_keypair does not support import in provider v0.6.

# VPS VM
import {
  for_each = (var.enable_vps && var.existing_vps_id != "") ? { this = var.existing_vps_id } : {}
  to       = module.vps[0].cloudstack_instance.this[0]
  id       = each.value
}

# Userdata scripts (native cloudstack_user_data resource)
import {
  for_each = { for k, v in var.existing_userdata_ids : k => v if v != "" }
  to       = module.userdata.cloudstack_user_data.this[each.key]
  id       = each.value
}


# ---------------------------------------------------------------------------
# Zone data source — used by modules that need zone_id (e.g. shared_filesystems)
# ---------------------------------------------------------------------------
data "cloudstack_zone" "this" {
  filter {
    name  = "name"
    value = var.zone_name
  }
}

# ---------------------------------------------------------------------------
# VPC + network tiers
# ---------------------------------------------------------------------------
module "vpc" {
  source = "../../modules/cloudstack-vpc"

  zone_name       = var.zone_name
  account_name    = var.account_name
  domain_id       = var.domain_id
  domain_name     = var.domain_name
  vpc_name        = var.vpc_name
  vpc_cidr        = var.vpc_cidr
  vpc_offering_name = var.vpc_offering_name
  vpc_networks    = var.vpc_networks
  default_acl_id  = var.default_acl_id

  existing_vpc_id      = var.existing_vpc_id
  existing_network_ids = var.existing_network_ids
}

# ---------------------------------------------------------------------------
# Isolated network (iso-net-shared)
# ---------------------------------------------------------------------------
module "isolated_network" {
  source = "../../modules/cloudstack-network"

  zone_name               = var.zone_name
  account_name            = var.account_name
  domain_id               = var.domain_id
  name                    = var.isolated_net_name
  display_text            = "Homecloud Shared Isolated Network"
  cidr                    = var.isolated_net_cidr
  gateway                 = var.isolated_net_gateway
  network_offering_name   = var.isolated_net_offering_name

  existing_network_id = var.existing_isolated_net_id
}

# ---------------------------------------------------------------------------
# SSH keypair (nulcell)
# ---------------------------------------------------------------------------
module "keypair" {
  count  = (var.enable_keypair && var.keypair_name != "") ? 1 : 0
  source = "../../modules/cloudstack-keypair"

  name         = var.keypair_name
  public_key   = local.nulcell_public_key
  domain_id    = var.domain_id
  account_name = var.account_name

  existing_keypair_id = var.existing_keypair_id
}

# ---------------------------------------------------------------------------
# User data scripts
# ---------------------------------------------------------------------------
module "userdata" {
  source = "../../modules/cloudstack-userdata"

  account_name = var.account_name
  domain_id    = var.domain_id
  scripts      = var.userdata_scripts
}

# ---------------------------------------------------------------------------
# NFS shared filesystems
# ---------------------------------------------------------------------------
module "shared_filesystems" {
  source = "../../modules/cloudstack-shared-filesystem"

  account_name = var.account_name
  domain_id    = var.domain_id
  zone_id      = data.cloudstack_zone.this.id
  zone_name    = var.zone_name
  enable       = var.enable_shared_storage
  filesystems  = var.shared_filesystems
}

# ---------------------------------------------------------------------------
# VPS VM (homecloud-vps)
# ---------------------------------------------------------------------------
module "vps" {
  count  = var.enable_vps ? 1 : 0
  source = "../../modules/cloudstack-vm"

  name           = var.vps.name
  zone_name      = var.zone_name
  account_name   = var.account_name
  domain_id      = var.domain_id
  template_name  = var.ubuntu_template_name
  offering_name  = var.vps.compute_offering
  root_disk_size = var.vps.root_disk_size
  network_ids    = [module.vpc.network_ids[var.vps.network_name]]
  keypair_name   = var.keypair_name
  userdata_id    = lookup(module.userdata.userdata_ids, var.vps.userdata_name, "")
  enable         = var.enable_vps

  existing_vm_id = var.existing_vps_id
}
