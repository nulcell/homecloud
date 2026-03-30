module "configuration" {
  source = "../../modules/cloudstack-configuration"

  global_settings = var.global_settings
  cmk_profile     = "admin"
}

module "zone" {
  source = "../../modules/cloudstack-zone"

  zone_name             = var.zone_name
  physical_networks     = var.physical_networks
  pod                   = var.pod
  cluster               = var.cluster
  hosts                 = var.hosts
  primary_storage_pools = var.primary_storage_pools
  secondary_storage     = var.secondary_storage
  cmk_profile           = "admin"

}

module "domain" {
  source = "../../modules/cloudstack-domain"

  domain_name        = var.domain_name
  domain_network     = var.domain_network
  account_name       = var.account_name
  resource_limits    = var.resource_limits
}

module "account" {
  source = "../../modules/cloudstack-account"

  account_name        = var.account_name
  account_type        = 2 # domain admin
  domain_id           = module.domain.domain_id
  email               = local._cs_homecloud_fields["Email"]
  firstname           = local._cs_homecloud_fields["First name"]
  lastname            = local._cs_homecloud_fields["Last name"]
  password            = data.onepassword_item.cs_homecloud_creds.password
  username            = data.onepassword_item.cs_homecloud_creds.username
}

module "offerings" {
  source = "../../modules/cloudstack-offerings"

  cmk_profile       = "admin"
  disk_offerings    = var.disk_offerings
  compute_offerings = var.compute_offerings
  network_offerings = var.network_offerings
  vpc_offerings     = var.vpc_offerings
}

module "templates" {
  source = "../../modules/cloudstack-templates"

  zone_id   = module.zone.zone_id
  zone_name = var.zone_name
  templates = var.templates
  isos      = var.isos
}

