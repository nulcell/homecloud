# ---------------------------------------------------------------------------
# Domain
# ---------------------------------------------------------------------------
resource "cloudstack_domain" "this" {
  name           = var.domain_name
  network_domain = var.domain_network
}

resource "cloudstack_limits" "this" {
  # Only iterate over resource types supported by provider v0.6 (keys "0"–"11").
  # CloudStack API returns additional type codes (12+) for backups/buckets/GPUs
  # that the TF provider does not yet implement.
  for_each = { for k, v in var.resource_limits : k => v
  if contains(keys(local.resource_type_map), k) }

  type      = local.resource_type_map[each.key]
  max       = each.value
  domain_id = cloudstack_domain.this.id

  depends_on = [cloudstack_domain.this]
}
