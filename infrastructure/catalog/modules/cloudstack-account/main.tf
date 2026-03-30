resource "cloudstack_account" "this" {
  account      = var.account_name
  account_type = var.account_type
  domain_id    = var.domain_id
  email        = var.email
  first_name   = var.firstname
  last_name    = var.lastname
  password     = var.password
  username     = var.username
  role_id      = local.resolved_role_id
}
