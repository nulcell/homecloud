variable "domain_name" {
  type        = string
  description = "Name of the CloudStack domain to create or manage."
}

variable "domain_network" {
  type        = string
  description = "Network domain suffix for the domain, e.g. homecloud.internal."
}

variable "account_name" {
  type        = string
  description = "Account name within the domain to which resource limits apply."
}

variable "resource_limits" {
  type        = map(number)
  description = "Map of resource type integer (as string key) → maximum value. See CloudStack resourcetype enumeration."
}
