# ---------------------------------------------------------------------------
# VM Instance
#
# service_offering and template both accept names directly — we pass
# var.offering_name / var.template_name to avoid UUID↔name drift (the
# CloudStack API returns names, not IDs, when reading resources back).
#
# Import blocks must be placed in the root module (stack); see stack main.tf.
# ---------------------------------------------------------------------------
resource "cloudstack_instance" "this" {
  count = var.enable ? 1 : 0

  name             = var.name
  display_name     = var.display_name != "" ? var.display_name : var.name
  service_offering = var.offering_name
  template         = var.template_name
  zone             = var.zone_name
  network_id       = var.network_ids[0]
  root_disk_size   = var.root_disk_size

  keypair = var.keypair_name != "" ? var.keypair_name : null

  # user_data_base64 takes precedence (e.g. raw Talos machine config).
  # Falls back to userdata_id when the CloudStack TF provider supports it.
  user_data    = var.user_data_base64 != "" ? var.user_data_base64 : null
  userdata_id  = var.user_data_base64 == "" && var.userdata_id != "" ? var.userdata_id : null

  # userdata_details: key/value substitution params for pre-registered userdata.
  userdata_details = (
    var.user_data_base64 == "" &&
    var.userdata_id != "" &&
    length(var.userdata_details) > 0
  ) ? var.userdata_details : null

  lifecycle {
    # Ignore changes to user_data after initial creation.
    # service_offering — CloudStack may report a different alias for the same
    # offering (e.g. "acs.comp.gen.xlarge" vs "gen.xlarge") on imported VMs.
    # keypair — adding a keypair to a running VM requires stop/reimage; ignore
    # for imported VMs (keypair is set at creation time for new VMs).
    # disk_offering — CloudStack reports back the offering name in a different
    # format than the API accepts; ignore to prevent spurious diffs on import.
    ignore_changes = [user_data, service_offering, keypair, disk_offering]
  }
}

# ---------------------------------------------------------------------------
# Additional NICs (for VMs that need more than one network)
#
# cloudstack_instance only supports a single primary network_id.
# Additional networks in var.network_ids are attached via cloudstack_nic.
# ---------------------------------------------------------------------------
resource "cloudstack_nic" "extra" {
  for_each = {
    for idx, net_id in(
      var.enable && length(var.network_ids) > 1
      ? slice(var.network_ids, 1, length(var.network_ids))
      : []
    ) : tostring(idx + 1) => net_id
  }

  virtual_machine_id = cloudstack_instance.this[0].id
  network_id         = each.value
}
