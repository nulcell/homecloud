variable "cloudstack_api_url" {
  type        = string
  description = "CloudStack API endpoint URL."
}

variable "zone_id" {
  type        = string
  description = "UUID of the CloudStack zone."
}

variable "zone_name" {
  type        = string
  default     = "zone-homecloud"
  description = "Name of the CloudStack zone."
}

variable "account_name" {
  type        = string
  default     = "homecloud"
  description = "CloudStack account name."
}

variable "domain_id" {
  type        = string
  default     = ""
  description = "UUID of the CloudStack domain. Leave empty when the API key is already scoped to the domain."
}

variable "network_ids" {
  type        = list(string)
  description = "Ordered list of network UUIDs to attach to the VPN router VM (all 5 networks)."
}

variable "template_id" {
  type        = string
  description = "UUID of the Ubuntu VM template for the VPN router."
}

variable "compute_offering_id" {
  type        = string
  description = "UUID of the CloudStack service offering for the VPN router VM."
}

variable "keypair_name" {
  type        = string
  description = "Name of the SSH keypair to inject into the VM."
}

variable "userdata_id" {
  type        = string
  description = "UUID of the pre-registered CloudStack userdata object (cloud-init template)."
}

variable "op_vault" {
  type        = string
  default     = "homecloud"
  description = "1Password vault name or UUID."
}

variable "op_tailscale_ref" {
  type        = string
  default     = ""
  description = "1Password item title for an existing Tailscale auth key. When set, reads the key from 1Password instead of generating a new one via the Tailscale API."
}

variable "vpn_cidr" {
  type        = string
  default     = "10.0.0.0/15"
  description = "CIDR of the subnet range that the VPN router will advertise to Tailscale."
}

variable "vm_name" {
  type        = string
  default     = "homecloud-vpn-router"
  description = "Name of the VPN router VM."
}

variable "root_disk_size_gb" {
  type        = number
  default     = 10
  description = "Root disk size for the VPN router VM in GB."
}

variable "existing_vm_id" {
  type        = string
  default     = ""
  description = "Existing VM UUID to import into state. Leave empty to create a new VM."
}
