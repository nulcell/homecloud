# ── Credentials ───────────────────────────────────────────────────────────────

variable "cloudstack_api_url" {
  type        = string
  description = "CloudStack API endpoint URL (e.g. http://10.10.17.5:8080/client/api)."
}

variable "op_vault" {
  type        = string
  description = "1Password vault name holding CloudStack credentials."
}

variable "op_account" {
  type        = string
  description = "1Password account URL (e.g. my.1password.com) for CLI-based provider auth."
}

variable "op_cs_homecloud_item" {
  type        = string
  default     = "CloudStack - homecloud-admin"
  description = "Title of the 1Password item containing homecloud account credentials."
}

# ── Zone identity ─────────────────────────────────────────────────────────────

variable "zone_name" {
  type        = string
  description = "Name of the CloudStack zone (must already exist; looked up via data source)."
}

# variable "zone_dns1" {
#   type        = string
#   description = "Primary DNS for the zone."
# }

# variable "zone_internal_dns1" {
#   type        = string
#   description = "Internal primary DNS for the zone."
# }

# variable "zone_network_type" {
#   type        = string
#   description = "Network type for the zone (e.g., 'Basic' or 'Advanced')."
#   # the value must be either 'Basic' or 'Advanced'
#   validation {
#     condition     = contains(["Basic", "Advanced"], var.zone_network_type)
#     error_message = "zone_network_type must be either 'Basic' or 'Advanced'."
#   }
# }

# ── Global configuration settings ────────────────────────────────────────────

variable "global_settings" {
  type        = map(string)
  default     = {}
  description = "Map of CloudStack configuration key → value to apply via updateConfiguration API."
}

# # ── Zone infrastructure ────────────────────────────────────────────────────────
# # All zone infrastructure is pre-existing and imported (set-once).

# variable "zone" {
#   type = object({
#     dns1                                = optional(string)
#     dns2                                = optional(string)
#     internal_dns1                       = optional(string)
#     guest_cidr                          = optional(string)
#     network_domain                      = optional(string)
#     local_storage_enabled               = optional(bool, false)
#     local_storage_enabled_for_system_vm = optional(bool, false)
#   })
#   default     = null
#   description = "Zone DNS and storage settings. Currently informational; zone must be pre-created and imported."
# }

# variable "physical_networks" {
#   type = map(object({
#     isolation_method  = string
#     traffic_types     = list(string)
#     network_speed     = optional(string, "10G")
#     vlan_range        = optional(string)
#     service_providers = optional(map(object({
#       service_list = optional(list(string), [])
#     })), {})
#     public_ip_range = optional(object({
#       gateway  = string
#       netmask  = string
#       start_ip = string
#       end_ip   = string
#       vlan     = string
#     }))
#   }))
#   default     = {}
#   description = "Map of physical network name → configuration."
# }

# variable "pod" {
#   type = object({
#     name     = string
#     gateway  = string
#     netmask  = string
#     start_ip = string
#     end_ip   = string
#   })
#   description = "Pod configuration for the zone."
# }

# variable "cluster" {
#   type = object({
#     name       = string
#     hypervisor = string
#   })
#   description = "KVM cluster configuration."
# }

# variable "hosts" {
#   type = map(object({
#     username = string
#   }))
#   default     = {}
#   description = "Map of host IP address → configuration."
# }

# variable "primary_storage_pools" {
#   type = map(object({
#     server = string
#     path   = string
#   }))
#   default     = {}
#   description = "Map of storage pool name → NFS primary storage configuration."
# }

# variable "secondary_storage" {
#   type = map(object({
#     server = string
#     path   = string
#   }))
#   default     = {}
#   description = "Map of image store name → NFS secondary storage configuration."
# }

variable "existing_domain_name" {
  type        = string
  default     = null
  description = "Pre-existing domain name. When non-empty, domain creation is skipped and this name is used."
}

variable "existing_account_name" {
  type        = string
  default     = null
  description = "Pre-existing account name. When non-empty, account creation is skipped and this name is used."
}

variable "domain_name" {
  type        = string
  description = "CloudStack domain name to create or manage."
}

variable "domain_network" {
  type        = string
  description = "Network domain suffix for the CloudStack domain (e.g. homecloud.internal)."
}

variable "account_name" {
  type        = string
  description = "CloudStack account name within the domain."
}

variable "timezone" {
  type        = string
  default     = "Europe/Amsterdam"
  description = "Timezone for the CloudStack account."
}

variable "resource_limits" {
  type        = map(number)
  default     = {}
  description = "Map of resource type integer (string key) → maximum value for the domain account."
}

# ── Disk Offerings ────────────────────────────────────────────────────────────

variable "disk_offerings" {
  type = map(object({
    display_text = string
    storage_type = string
    customized   = optional(bool, false)
    disk_size    = optional(number)
  }))
  default     = {}
  description = "Disk offerings to manage."
}

# ── Compute Offerings ─────────────────────────────────────────────────────────

variable "compute_offerings" {
  type = map(object({
    display_text   = string
    cpu_number     = optional(number)
    cpu_speed      = optional(number, 2500)
    memory         = optional(number)
    network_rate   = optional(number, 1024)
    offer_ha       = optional(bool, true)
    disk_type      = string
    root_disk_size = optional(number)
    storage_type   = optional(string)
    is_customized  = optional(bool, false)
    min_cpu        = optional(number)
    max_cpu        = optional(number)
    min_memory     = optional(number)
    max_memory     = optional(number)
  }))
  default     = {}
  description = "Compute (service) offerings to manage."
}

# ── Network Offerings ─────────────────────────────────────────────────────────

variable "network_offerings" {
  type = map(object({
    display_text     = string
    guest_ip_type    = string
    for_vpc          = bool
    is_persistent    = optional(bool, false)
    specify_vlan     = optional(bool, false)
    redundant_router = optional(bool, false)
    lb_type          = optional(string)
    lb_provider      = optional(string)
    services         = list(string)
  }))
  default     = {}
  description = "Network offerings to manage."
}

# ── VPC Offerings ─────────────────────────────────────────────────────────────

variable "vpc_offerings" {
  type = map(object({
    display_text     = string
    redundant_router = optional(bool, false)
    services         = list(string)
  }))
  default     = {}
  description = "VPC offerings to manage."
}

# ── Templates / ISOs ──────────────────────────────────────────────────────────

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
  description = "OS templates to register via cloudstack_template (direct-download URLs only)."
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
  description = "ISOs to register via cmk CLI (null_resource)."
}

variable "enable_isos" {
  type        = bool
  default     = true
  description = "Set to false to skip ISO registration."
}
