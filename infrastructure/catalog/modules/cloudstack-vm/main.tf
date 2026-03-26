# ---------------------------------------------------------------------------
# VM Instance
#
# Import blocks must be placed in the root module (stack); see stack main.tf.
# ---------------------------------------------------------------------------
resource "cloudstack_instance" "this" {
  count = var.enable ? 1 : 0

  name             = var.name
  display_name     = var.display_name != "" ? var.display_name : var.name
  service_offering = var.offering_id
  template         = var.template_id
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
    ignore_changes = [user_data]
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
