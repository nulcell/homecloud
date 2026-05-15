variable "name" {
  type        = string
  description = "Name of the VM instance."
}

variable "display_name" {
  type        = string
  default     = ""
  description = "Display name for the VM. Defaults to name if empty."
}

variable "zone_name" {
  type        = string
  description = "Name of the CloudStack zone."
}

variable "account_name" {
  type        = string
  description = "CloudStack account name that owns the VM."
}

variable "domain_id" {
  type        = string
  description = "UUID of the CloudStack domain."
}

variable "template_name" {
  type        = string
  description = "Name of the VM template (e.g. 'Ubuntu 24.04 - Noble'). Looked up via data source."
}

variable "offering_name" {
  type        = string
  description = "Name of the service offering (e.g. 'gen.xlarge'). Looked up via data source."
}

variable "root_disk_size" {
  type        = number
  default     = 20
  description = "Root disk size in GB."
}

variable "network_ids" {
  type        = list(string)
  description = "Ordered list of network UUIDs. The first entry is the primary NIC."
}

variable "keypair_name" {
  type        = string
  default     = ""
  description = "Name of the SSH keypair to inject. Leave empty to skip."
}

variable "userdata_id" {
  type        = string
  default     = ""
  description = "UUID of a pre-registered CloudStack userdata object. Used when the CloudStack TF provider supports user_data_id on cloudstack_instance."
}

variable "userdata_details" {
  type        = map(string)
  default     = {}
  sensitive   = true
  description = "Key/value params for userdata template substitution (userdatadetails)."
}

variable "user_data_base64" {
  type        = string
  default     = ""
  sensitive   = true
  description = "Raw base64-encoded user_data (e.g. Talos machine config). Takes precedence over userdata_id when set."
}

variable "enable" {
  type        = bool
  default     = true
  description = "Set to false to skip VM creation without removing the config block."
}

variable "existing_vm_id" {
  type        = string
  default     = ""
  description = "Existing VM UUID to import into state. Only used when enable = true."
}

variable "tags" {
  type        = map(string)
  default     = {}
  description = "Resource tags to apply to the VM."
}
