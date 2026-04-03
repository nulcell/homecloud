# ---------------------------------------------------------------------------
# Templates
# prevent_destroy = true: templates must be manually deregistered.
# To update a template URL, taint the resource and reapply — CloudStack will
# re-download. If VMs are running from it, stop them first.
# ---------------------------------------------------------------------------

resource "cloudstack_template" "this" {
  for_each = var.templates

  name                    = each.value.name
  display_text            = each.value.display_text
  url                     = each.value.url
  format                  = each.value.format
  hypervisor              = each.value.hypervisor
  zone                    = var.zone_name
  os_type                 = each.value.os_type
  is_featured             = each.value.is_featured
  is_public               = each.value.is_public
  is_extractable          = each.value.is_extractable
  is_dynamically_scalable = each.value.is_dynamically_scalable
  password_enabled        = each.value.password_enabled

  # lifecycle {
  #   prevent_destroy = true
  # }
}

# Update template configs using cmk CLI since cloudstack_template does not support in-place updates.
resource "null_resource" "template_update" {
  for_each = { for k, v in var.templates : k => v if length(v.details) > 0 }

  triggers = {
    hash = sha256(jsonencode(each.value.details))
  }

  provisioner "local-exec" {
    command = <<-EOT
      TEMPLATE_ID=${cloudstack_template.this[each.key].id}
      cmk -p admin update template id="$TEMPLATE_ID" \
        ${join(" \\\n        ", [
    for k, v in each.value.details :
    "details[0].${k}=\"${v}\""
])}
    EOT
}
}

# ---------------------------------------------------------------------------
# ---------------------------------------------------------------------------
# ISOs
# The cloudstack_template resource does not support ISO registration.
# ISOs are registered via cmk CLI using null_resource + local-exec.
#
# NOTE: null_resource does not support lifecycle { prevent_destroy = true }.
# To protect ISOs from accidental deletion, remove them from the isos map
# rather than relying on Terraform lifecycle guards.
# ---------------------------------------------------------------------------
resource "null_resource" "iso" {
  # Only create ISOs when enable_isos = true
  for_each = var.enable_isos ? var.isos : {}

  triggers = {
    # Re-runs only when ISO definition changes (URL, name, etc.)
    hash = sha256(jsonencode(each.value))
  }

  provisioner "local-exec" {
    command = <<-EOT
      EXISTING=$(cmk -p admin list isos \
        name='${each.value.name}' \
        zoneid='${var.zone_id}' \
        isofilter=all | jq -r '.iso[0].id'  )

      if [ -z "$EXISTING" ]; then
        cmk -p admin register iso \
          name='${each.value.name}' \
          displaytext='${each.value.display_text}' \
          url='${each.value.url}' \
          zoneid='${var.zone_id}' \
          ostypeid=$(cmk -p admin list ostypes description='${each.value.os_type}' | jq -r '.ostype[0].id') \
          bootable=${each.value.bootable} \
          isfeatured=${each.value.is_featured} \
          ispublic=true \
          isextractable=false
      else
        echo "ISO '${each.value.name}' already registered (id=$EXISTING), skipping."
      fi
    EOT
  }
}
