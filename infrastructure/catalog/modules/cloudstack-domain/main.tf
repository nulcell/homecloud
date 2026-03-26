# ---------------------------------------------------------------------------
# Domain
# ---------------------------------------------------------------------------
resource "cloudstack_domain" "this" {
  name           = var.domain_name
  network_domain = var.domain_network
}

# ---------------------------------------------------------------------------
# Per-account resource limits
# resource_type keys are integer strings matching CloudStack resourcetype enum:
#   0=user_vm, 1=public_ip, 2=volume, 3=snapshot, 4=template,
#   6=network, 7=vpc, 8=cpu, 9=memory, 10=primary_storage, 11=secondary_storage
# ---------------------------------------------------------------------------
# cloudstack_limits uses string type names, not integers.
# Map from CloudStack resourcetype integer → provider type string.
locals {
  resource_type_map = {
    "0"  = "instance"
    "1"  = "ip"
    "2"  = "volume"
    "3"  = "snapshot"
    "4"  = "template"
    "5"  = "project"
    "6"  = "network"
    "7"  = "vpc"
    "8"  = "cpu"
    "9"  = "memory"
    "10" = "primarystorage"
    "11" = "secondarystorage"
  }
}

resource "cloudstack_limits" "this" {
  for_each = var.resource_limits

  type      = local.resource_type_map[each.key]
  max       = each.value
  domain_id = cloudstack_domain.this.id
  account   = var.account_name

  depends_on = [cloudstack_domain.this]
}
