variable "vault" {
  type        = string
  description = "Name or UUID of the 1Password vault containing the item."
}

variable "title" {
  type        = string
  description = "Title of the 1Password item to read (and optionally update)."
}

variable "fields" {
  type        = map(string)
  default     = {}
  sensitive   = true
  description = "Fields to write to the 1Password item (field label → value). Empty map = read-only mode; no resource is created."
}
