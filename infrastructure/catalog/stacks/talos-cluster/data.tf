data "onepassword_item" "cs_homecloud" {
  vault = var.op_vault
  title = "CloudStack - homecloud-admin"
}
