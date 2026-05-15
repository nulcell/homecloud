# For domain-admin accounts (account_type = 2) the default "Domain Admin" role
# is used unless an explicit role_id is provided.
data "cloudstack_role" "domain_admin" {
  count = var.role_id == "" ? 1 : 0
  filter {
    name  = "name"
    value = "Domain Admin"
  }
}
