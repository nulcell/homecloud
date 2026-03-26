# ---------------------------------------------------------------------------
# Read item from 1Password
# ---------------------------------------------------------------------------
data "onepassword_item" "this" {
  vault = var.vault
  title = var.title
}

# ---------------------------------------------------------------------------
# Optionally write fields back into the item
# Only created when var.fields is non-empty.
# ---------------------------------------------------------------------------
resource "onepassword_item" "this" {
  count = length(var.fields) > 0 ? 1 : 0

  vault = var.vault
  title = var.title

  dynamic "field" {
    for_each = var.fields
    content {
      label = field.key
      value = field.value
      type  = "STRING"
    }
  }
}
