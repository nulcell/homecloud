locals {
  resolved_role_id = var.role_id != "" ? var.role_id : data.cloudstack_role.domain_admin[0].id
}
