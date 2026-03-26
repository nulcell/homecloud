# ---------------------------------------------------------------------------
# Isolated Network
# ---------------------------------------------------------------------------
resource "cloudstack_network" "this" {
  name             = var.name
  display_text     = var.display_text
  cidr             = var.cidr
  gateway          = var.gateway
  network_offering = var.network_offering_id
  zone             = var.zone_name
}
