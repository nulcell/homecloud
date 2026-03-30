# ---------------------------------------------------------------------------
# Isolated Network
# network_offering accepts names directly; we pass the name to avoid
# UUID↔name drift (CloudStack API returns names, not IDs).
# ---------------------------------------------------------------------------
resource "cloudstack_network" "this" {
  name             = var.name
  display_text     = var.display_text
  cidr             = var.cidr
  gateway          = var.gateway
  network_offering = var.network_offering_name
  zone             = var.zone_name

  lifecycle {
    # display_text may differ from the imported value.
    ignore_changes = [display_text]
  }
}
