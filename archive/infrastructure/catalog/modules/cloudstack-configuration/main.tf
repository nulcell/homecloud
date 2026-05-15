# Each CloudStack global configuration key is applied via updateConfiguration API.
# null_resource is used because there is no native Terraform resource for this.
# Each resource re-runs when its value changes (trigger on value hash).
resource "null_resource" "setting" {
  for_each = var.global_settings

  triggers = {
    value = each.value
  }

  provisioner "local-exec" {
    command = "cmk -p ${var.cmk_profile} update configuration name='${each.key}' value='${each.value}'"
  }
}
