variable "zone_id" {
  type        = string
  description = "UUID of the CloudStack zone where templates/ISOs are registered."
}

variable "zone_name" {
  type        = string
  description = "Name of the CloudStack zone (used by cloudstack_template resource)."
}

variable "templates" {
  type = map(object({
    name                    = string
    display_text            = string
    url                     = string
    format                  = string
    hypervisor              = string
    os_type                 = string
    is_featured             = optional(bool, false)
    is_public               = optional(bool, true)
    is_extractable          = optional(bool, false)
    is_dynamically_scalable = optional(bool, true)
    password_enabled        = optional(bool, false)
    details                 = optional(map(string), {})
  }))
  default     = {}
  description = "Map of template key → configuration. All templates get lifecycle { prevent_destroy = true }."
}

variable "isos" {
  type = map(object({
    name         = string
    display_text = string
    url          = string
    os_type      = string
    bootable     = optional(bool, true)
    is_featured  = optional(bool, false)
  }))
  default     = {}
  description = "Map of ISO key → configuration. Managed via null_resource + cmk CLI."
}

variable "enable_isos" {
  type        = bool
  default     = true
  description = "Set to false to skip ISO registration entirely."
}

variable "existing_template_ids" {
  type        = map(string)
  default     = {}
  description = "Map of template key → existing UUID for Terraform import."
}

variable "existing_iso_ids" {
  type        = map(string)
  default     = {}
  description = "Map of ISO key → existing UUID. ISOs are managed by null_resource; this is informational only."
}
