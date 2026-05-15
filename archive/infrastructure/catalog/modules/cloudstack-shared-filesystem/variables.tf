variable "account_name" {
  type        = string
  description = "CloudStack account name the shared filesystems are created under."
}

variable "domain_id" {
  type        = string
  description = "UUID of the CloudStack domain."
}

variable "zone_id" {
  type        = string
  description = "UUID of the CloudStack zone."
}

variable "zone_name" {
  type        = string
  description = "Name of the CloudStack zone."
}

variable "cmk_profile" {
  type        = string
  default     = "homecloud-admin"
  description = "CloudMonkey CLI profile name to use for createSharedFileSystem commands."
}

variable "enable" {
  type        = bool
  default     = true
  description = "Set to false to disable all shared filesystem creation without removing entries from the map."
}

variable "filesystems" {
  type = map(object({
    size_gb          = number
    service_offering = string
    disk_offering    = string
    network_name     = string
    filesystem       = optional(string, "XFS")
    provider_name    = optional(string, "SHAREDFSVM")
  }))
  default     = {}
  description = "Map of filesystem name → config. Removing an entry from the map WILL delete that filesystem on next apply (data loss — do deliberately)."
}
