# Read CloudStack root admin API credentials from 1Password.
# Used to configure the cloudstack provider below.
data "onepassword_item" "cs_admin" {
  vault = var.op_vault
  title = "CloudStack - admin"
}

# Build a flat label → value map from all section fields.
# Store the CloudStack API credentials in a 1Password item under a section
# with fields labelled "api key" and "secret key".
locals {
  _cs_admin_fields = merge([
    for s in data.onepassword_item.cs_admin.section : {
      for f in s.field : f.label => f.value
    }
  ]...)
}

provider "cloudstack" {
  api_url    = var.cloudstack_api_url
  api_key    = local._cs_admin_fields["api-key"]
  secret_key = local._cs_admin_fields["secret-key"]
}

provider "onepassword" {
  account = var.op_account
}
