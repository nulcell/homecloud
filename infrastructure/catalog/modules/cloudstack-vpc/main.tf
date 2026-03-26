# ---------------------------------------------------------------------------
# VPC
# ---------------------------------------------------------------------------
resource "cloudstack_vpc" "this" {
  name         = var.vpc_name
  display_text = var.vpc_name
  vpc_offering = var.vpc_offering_id
  cidr         = var.vpc_cidr
  zone         = var.zone_name
}

# ---------------------------------------------------------------------------
# VPC Network Tiers
#
# Note: When the global setting vpc.tier.name.prepend = true (default in this
# environment), CloudStack automatically prepends the VPC name to the stored
# network name (e.g. "pub-net-1" → "homecloud-vpc_pub-net-1").  We set
# name = each.key here; CloudStack handles the prefix internally.
# ---------------------------------------------------------------------------
resource "cloudstack_network" "tiers" {
  for_each = var.vpc_networks

  name             = each.key
  display_text     = each.key
  cidr             = each.value.cidr
  gateway          = each.value.gateway
  network_offering = each.value.offering_id
  vpc_id           = cloudstack_vpc.this.id
  zone             = var.zone_name

  # Apply the default_allow ACL when provided.
  # Look up the ACL UUID with:
  #   cmk -p homecloud-admin list networkacllists name=default_allow vpcid=<VPC_ID>
  acl_id = var.default_acl_id != "" ? var.default_acl_id : null
}
