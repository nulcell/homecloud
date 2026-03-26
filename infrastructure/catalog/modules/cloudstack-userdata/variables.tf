variable "scripts" {
  type = map(object({
    file   = string
    params = optional(list(string), [])
  }))
  description = "Map of userdata name → { file path, optional params list }."
}

variable "account_name" {
  type        = string
  description = "CloudStack account name to scope the userdata to."
}

variable "domain_id" {
  type        = string
  description = "CloudStack domain UUID to scope the userdata to."
}

variable "existing_userdata_ids" {
  type        = map(string)
  default     = {}
  description = "Map of userdata name → UUID for importing existing registrations."
}
