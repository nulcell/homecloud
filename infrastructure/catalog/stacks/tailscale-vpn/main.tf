# ---------------------------------------------------------------------------
# Tailscale auth key (only generated when op_tailscale_ref is empty)
# ---------------------------------------------------------------------------
module "tailscale_key" {
  count  = var.op_tailscale_ref == "" ? 1 : 0
  source = "../../modules/tailscale-key"

  description    = var.vm_name
  reusable       = false
  ephemeral      = false
  tags           = ["tag:subnet-router"]
  expiry_seconds = 3600
}

# ---------------------------------------------------------------------------
# VPN router VM
# ---------------------------------------------------------------------------
module "router_vm" {
  source = "../../modules/cloudstack-vm"

  name           = var.vm_name
  zone_name      = var.zone_name
  account_name   = var.account_name
  domain_id      = var.domain_id
  template_name  = var.template_name
  offering_name  = var.compute_offering_name
  root_disk_size = var.root_disk_size_gb
  network_ids    = var.network_ids
  keypair_name   = var.keypair_name
  userdata_id    = var.userdata_id
  userdata_details = {
    tailscale_auth_key  = local.tailscale_auth_key
    network_router_cidr = var.vpn_cidr
  }
  existing_vm_id = var.existing_vm_id
}
