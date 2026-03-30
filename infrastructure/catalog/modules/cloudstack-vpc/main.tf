# ---------------------------------------------------------------------------
# VPC
# vpc_offering accepts the offering name directly (no data source for VPC offerings).
# ---------------------------------------------------------------------------
resource "cloudstack_vpc" "this" {
  name         = var.vpc_name
  display_text = var.vpc_name
  vpc_offering = var.vpc_offering_name
  cidr         = var.vpc_cidr
  zone         = var.zone_name

  lifecycle {
    # display_text may differ from the imported value (CloudStack stores a
    # human-friendly description that we don't control post-creation).
    ignore_changes = [display_text]
  }
}

# ---------------------------------------------------------------------------
# VPC Network Tiers
#
# network_offering accepts names directly; we pass the name to avoid
# UUID↔name drift (CloudStack API returns names, not IDs).
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
  network_offering = each.value.offering_name
  vpc_id           = cloudstack_vpc.this.id
  zone             = var.zone_name

  # Apply the default_allow ACL when provided.
  # Look up the ACL UUID with:
  #   cmk -p homecloud-admin list networkacllists name=default_allow vpcid=<VPC_ID>
  acl_id = var.default_acl_id != "" ? var.default_acl_id : null

  lifecycle {
    # display_text — CloudStack stores a human-friendly description set at
    # creation time; we don't manage it post-import.
    # name — CloudStack prepends the VPC name (vpc.tier.name.prepend=true) so
    # the stored value differs from the short key we pass.
    ignore_changes = [display_text, name]
  }
}
