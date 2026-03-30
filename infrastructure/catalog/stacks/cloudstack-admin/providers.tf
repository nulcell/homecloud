provider "cloudstack" {
  api_url    = var.cloudstack_api_url
  api_key    = local._cs_admin_fields["api-key"]
  secret_key = local._cs_admin_fields["secret-key"]
}

provider "onepassword" {
  account = var.op_account
}
