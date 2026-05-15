variable "zone_name" {
  type        = string
  description = "Name of the CloudStack zone."
}

variable "account_name" {
  type        = string
  description = "CloudStack account name that owns the network."
}

variable "domain_id" {
  type        = string
  description = "UUID of the CloudStack domain."
}

variable "name" {
  type        = string
  description = "Name of the isolated network."
}

variable "display_text" {
  type        = string
  description = "Display text / description for the isolated network."
}

variable "cidr" {
  type        = string
  description = "CIDR block for the isolated network (e.g. 10.1.1.0/24)."
}

variable "gateway" {
  type        = string
  description = "Gateway IP address for the isolated network."
}

variable "netmask" {
  type        = string
  default     = "255.255.255.0"
  description = "Netmask for the isolated network."
}

variable "network_offering_name" {
  type        = string
  description = "Name of the network offering (e.g. 'isolated.core-redundant'). Looked up via data source."
}

variable "existing_network_id" {
  type        = string
  default     = ""
  description = "Existing network UUID to import. Leave empty to create a new network."
}
