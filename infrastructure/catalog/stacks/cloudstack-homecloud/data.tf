data "onepassword_item" "cs_homecloud" {
  vault = var.op_vault
  title = var.op_cs_homecloud_item
}

# SSH public key for keypair registration (SSH Key item type in 1Password)
data "onepassword_item" "nulcell_key" {
  vault = var.op_vault
  title = "nulcell"
}

data "cloudstack_zone" "this" {
  filter {
    name  = "name"
    value = var.zone_name
  }
}
