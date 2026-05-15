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
resource "cloudstack_limits" "this" {
  # Only iterate over resource types supported by provider v0.6 (keys "0"–"11").
  # CloudStack API returns additional type codes (12+) for backups/buckets/GPUs
  # that the TF provider does not yet implement.
  for_each = { for k, v in var.resource_limits : k => v
  if contains(keys(local.resource_type_map), k) }

  type      = local.resource_type_map[each.key]
  max       = each.value
  domain_id = var.domain_id
  account   = var.account_name
}
