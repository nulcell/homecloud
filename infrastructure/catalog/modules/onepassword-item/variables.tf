variable "vault" {
  type        = string
  description = "UUID of the 1Password vault containing the item."
}

variable "title" {
  type        = string
  description = "Title of the 1Password item."
}

variable "category" {
  type        = string
  default     = "secure_note"
  description = "1Password item category. One of: login, password, database, secure_note."
}

variable "note_value" {
  type        = string
  default     = ""
  sensitive   = true
  description = "Secure note body. Required when category = secure_note."
}

variable "fields" {
  type        = map(string)
  default     = {}
  sensitive   = true
  description = "Section fields to write (label → value). Empty map = read-only mode."
}
