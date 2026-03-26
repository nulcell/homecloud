variable "zone_id" {
  type        = string
  description = "UUID of the CloudStack zone."
}

variable "zone_name" {
  type        = string
  description = "Name of the CloudStack zone."
}

variable "account_name" {
  type        = string
  description = "CloudStack account name that owns the VPC."
}

variable "domain_id" {
  type        = string
  description = "UUID of the CloudStack domain."
}

variable "domain_name" {
  type        = string
  description = "Name of the CloudStack domain."
}

variable "vpc_name" {
  type        = string
  description = "Name of the VPC to create."
}

variable "vpc_cidr" {
  type        = string
  description = "CIDR block for the VPC (e.g. 10.0.0.0/24)."
}

variable "vpc_offering_id" {
  type        = string
  description = "UUID of the VPC offering to use."
}

variable "vpc_networks" {
  type = map(object({
    cidr        = string
    gateway     = string
    offering_id = string
  }))
  description = "Map of network tier name → config. Keys become CloudStack network names. CloudStack prepends the VPC name when vpc.tier.name.prepend = true (e.g. homecloud-vpc_pub-net-1)."
}

variable "default_acl_id" {
  type        = string
  default     = ""
  description = "UUID of the default_allow network ACL to apply to all VPC network tiers. Look up with: cmk -p homecloud-admin list networkacllists name=default_allow vpcid=<VPC_ID>. Leave empty to omit explicit ACL assignment."
}

variable "existing_vpc_id" {
  type        = string
  default     = ""
  description = "Existing VPC UUID to import. Leave empty to create a new VPC."
}

variable "existing_network_ids" {
  type        = map(string)
  default     = {}
  description = "Map of network tier key → existing network UUID to import. Keys must match vpc_networks map keys."
}
