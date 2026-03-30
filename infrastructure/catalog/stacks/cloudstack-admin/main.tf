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
  count  = var.domain_id == "" ? 1 : 0
  source = "../../modules/cloudstack-domain"

  domain_name        = var.domain_name
  domain_network     = var.domain_network
  account_name       = var.account_name
  resource_limits    = var.resource_limits
}

module "account" {
  count  = var.account_id == "" ? 1 : 0
  source = "../../modules/cloudstack-account"

  account_name        = var.account_name
  account_type        = 2 # domain admin
  domain_id           = local.resolved_domain_id
  email               = local._cs_homecloud_fields["Email"]
  firstname           = local._cs_homecloud_fields["First name"]
  lastname            = local._cs_homecloud_fields["Last name"]
  password            = data.onepassword_item.cs_homecloud_creds.password
  username            = data.onepassword_item.cs_homecloud_creds.username
}

# When the account is freshly created, generate its API key and write to 1Password
# so downstream units can configure their cloudstack provider on the next apply.
resource "null_resource" "homecloud_api_key" {
  count = var.account_id == "" ? 1 : 0

  triggers = {
    account_id = module.account[0].account_id
  }

  provisioner "local-exec" {
    command = <<-EOT
      USER_ID=$(cmk -p admin list users \
        account='${var.account_name}' \
        domainid='${local.resolved_domain_id}' \
        --output text --filter id | head -1)

      RESULT=$(cmk -p admin createApiKey id="$USER_ID")
      API_KEY=$(echo "$RESULT"    | jq -r '.apikeys.apikey')
      SECRET_KEY=$(echo "$RESULT" | jq -r '.apikeys.secretkey')

      op item edit '${var.op_cs_homecloud_item}' \
        --vault '${var.op_vault}' \
        "api-key=$API_KEY" \
        "secret-key=$SECRET_KEY"
    EOT
  }
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

