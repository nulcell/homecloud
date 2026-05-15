data "onepassword_item" "this" {
  count = length(var.fields) == 0 ? 1 : 0
  vault = var.vault
  title = var.title
}
