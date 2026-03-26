# ---------------------------------------------------------------------------
# Role lookup (data source) — used to assign the correct role to the account.
# For domain-admin accounts (account_type = 2) the default "Domain Admin" role
# is used unless an explicit role_id is provided.
# ---------------------------------------------------------------------------
data "cloudstack_role" "domain_admin" {
  count = var.role_id == "" ? 1 : 0
  filter {
    name  = "name"
    value = "Domain Admin"
  }
}

locals {
  resolved_role_id = var.role_id != "" ? var.role_id : data.cloudstack_role.domain_admin[0].id
}

# ---------------------------------------------------------------------------
# Account
# Import: set existing_account_id to the CloudStack account UUID to import.
#   cmk -p admin list accounts name=<name> domainid=<domain_id> --output text --filter id
# ---------------------------------------------------------------------------
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
