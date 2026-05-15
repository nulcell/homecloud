resource "onepassword_item" "this" {
  count      = length(var.fields) > 0 ? 1 : 0
  vault      = var.vault
  title      = var.title
  category   = var.category
  note_value = var.note_value != "" ? var.note_value : null

  section {
    label = "Fields"

    dynamic "field" {
      for_each = var.fields
      content {
        label = field.key
        value = field.value
        type  = "CONCEALED"
      }
    }
  }
}
