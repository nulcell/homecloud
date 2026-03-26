# ---------------------------------------------------------------------------
# User Data Scripts
# Registers cloud-init scripts in CloudStack using the native cloudstack_user_data
# resource (available since provider v0.6.0).
#
# Import: populate existing_userdata_ids[name] = UUID to import existing scripts.
#   cmk -p homecloud-admin list userdata account=homecloud domainid=<domain_id>
# ---------------------------------------------------------------------------

resource "cloudstack_user_data" "this" {
  for_each = var.scripts

  name      = each.key
  userdata  = base64encode(file(each.value.file))
  params    = length(each.value.params) > 0 ? each.value.params : null
  account   = var.account_name
  domain_id = var.domain_id
}
