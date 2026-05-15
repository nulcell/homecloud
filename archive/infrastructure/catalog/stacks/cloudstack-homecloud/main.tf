module "vpc" {
  source = "../../modules/cloudstack-vpc"

  zone_name         = var.zone_name
  account_name      = var.account_name
  domain_id         = var.domain_id
  domain_name       = var.domain_name
  vpc_name          = var.vpc_name
  vpc_cidr          = var.vpc_cidr
  vpc_offering_name = var.vpc_offering_name
  vpc_networks      = var.vpc_networks
  default_acl_id    = var.default_acl_id
}

module "isolated_network" {
  source = "../../modules/cloudstack-network"

  zone_name             = var.zone_name
  account_name          = var.account_name
  domain_id             = var.domain_id
  name                  = var.isolated_net_name
  display_text          = "Homecloud Shared Isolated Network"
  cidr                  = var.isolated_net_cidr
  gateway               = var.isolated_net_gateway
  network_offering_name = var.isolated_net_offering_name
}

module "keypair" {
  count  = var.keypair_name != null ? 1 : 0
  source = "../../modules/cloudstack-keypair"

  name         = var.keypair_name
  public_key   = local.nulcell_public_key
  domain_id    = var.domain_id
  account_name = var.account_name
}

module "userdata" {
  source = "../../modules/cloudstack-userdata"

  account_name = var.account_name
  domain_id    = var.domain_id
  scripts      = var.userdata_scripts
}

module "shared_filesystems" {
  count  = var.enable_shared_storage ? 1 : 0
  source = "../../modules/cloudstack-shared-filesystem"

  account_name = var.account_name
  domain_id    = var.domain_id
  zone_id      = data.cloudstack_zone.this.id
  zone_name    = var.zone_name
  filesystems  = var.shared_filesystems
}

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
}
