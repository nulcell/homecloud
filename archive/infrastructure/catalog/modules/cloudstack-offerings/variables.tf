variable "disk_offerings" {
  type = map(object({
    display_text = string
    storage_type = string
    customized   = optional(bool, false)
    disk_size    = optional(number) # GiB; null for customized
  }))
  default     = {}
  description = "Map of disk offering name → configuration."
}

variable "compute_offerings" {
  # disk_type: "custom_shared" | "custom_local" | "fixed" | "customized"
  # For "custom_shared"/"custom_local": uses a named disk_offering from this module
  # For "fixed": storage_type + root_disk_size baked in
  # For "customized": fully custom CPU+RAM (set is_customized = true)
  type = map(object({
    display_text   = string
    cpu_number     = optional(number)
    cpu_speed      = optional(number, 2500)
    memory         = optional(number)
    network_rate   = optional(number, 1024)
    offer_ha       = optional(bool, true)
    disk_type      = string
    root_disk_size = optional(number) # for disk_type = "fixed" only
    storage_type   = optional(string) # "shared"/"local" for disk_type = "fixed"
    # For customized (is_customized = true):
    is_customized = optional(bool, false)
    min_cpu       = optional(number)
    max_cpu       = optional(number)
    min_memory    = optional(number)
    max_memory    = optional(number)
  }))
  default     = {}
  description = "Map of compute offering name → configuration."
}

variable "network_offerings" {
  type = map(object({
    display_text     = string
    guest_ip_type    = string # "Shared" | "Isolated"
    for_vpc          = bool
    is_persistent    = optional(bool, false)
    specify_vlan     = optional(bool, false)
    redundant_router = optional(bool, false)
    lb_type          = optional(string) # "publicLb" | "internalLb" | null
    lb_provider      = optional(string) # "VirtualRouter" | "InternalLbVm" | "VpcVirtualRouter" | null
    services         = list(string)
  }))
  default     = {}
  description = "Map of network offering name → configuration."
}

variable "vpc_offerings" {
  type = map(object({
    display_text     = string
    redundant_router = optional(bool, false)
    services         = list(string)
  }))
  default     = {}
  description = "Map of VPC offering name → configuration."
}

# ── Import variables (name → UUID) ────────────────────────────────────────────

variable "existing_disk_offering_ids" {
  type        = map(string)
  default     = {}
  description = "Map of disk offering name → existing UUID for Terraform import."
}

variable "existing_compute_offering_ids" {
  type        = map(string)
  default     = {}
  description = "Map of compute offering name → existing UUID for Terraform import."
}

variable "existing_network_offering_ids" {
  type        = map(string)
  default     = {}
  description = "Map of network offering name → existing UUID for Terraform import."
}

variable "existing_vpc_offering_ids" {
  type        = map(string)
  default     = {}
  description = "Map of VPC offering name → existing UUID for Terraform import."
}

variable "custom_disk_offering_ids" {
  type        = map(string)
  default     = {}
  description = "Map of customized disk offering name → CloudStack UUID (e.g. shared.custom, local.custom). Populated after first apply via cmk list diskofferings."
}

variable "cmk_profile" {
  type        = string
  description = "CloudMonkey CLI profile name for cmk commands (customized disk offerings, VPC offerings). Must match a profile in ~/.cloudmonkey/config."
}
