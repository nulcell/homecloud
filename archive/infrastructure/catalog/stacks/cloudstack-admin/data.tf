# Read CloudStack root admin API credentials from 1Password.
# Used to configure the cloudstack provider below.
data "onepassword_item" "cs_admin" {
  vault = var.op_vault
  title = "CloudStack - admin"
}

# Read homecloud account credentials from 1Password.
# Store this item with a section containing fields labelled:
#   "email", "First name", "Last name", "username", "password"
data "onepassword_item" "cs_homecloud_creds" {
  vault = var.op_vault
  title = var.op_cs_homecloud_item
}

data "cloudstack_zone" "this" {
  filter {
    name  = "name"
    value = var.zone_name
  }
}

data "cloudstack_domain" "this" {
  count = var.existing_domain_name != null ? 1 : 0
  filter {
    name  = "name"
    value = var.existing_domain_name
  }
}
