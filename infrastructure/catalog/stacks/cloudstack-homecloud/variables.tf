# ── CloudStack / provider ─────────────────────────────────────────────────

variable "cloudstack_api_url" {
  type        = string
  description = "CloudStack API endpoint URL."
}

variable "op_vault" {
  type        = string
  description = "1Password vault name where homecloud secrets live."
}

variable "op_cs_homecloud_item" {
  type        = string
  default     = "CloudStack - homecloud-admin"
  description = "1Password item title for the homecloud-admin CloudStack credentials."
}

# ── Zone / Domain / Account ───────────────────────────────────────────────

variable "zone_id" {
  type        = string
  description = "UUID of the CloudStack zone (from cloudstack-admin outputs)."
}

variable "zone_name" {
  type        = string
  default     = "zone-homecloud"
  description = "Name of the CloudStack zone."
}

variable "domain_id" {
  type        = string
  description = "UUID of the homecloud domain (from cloudstack-admin outputs)."
}

variable "domain_name" {
  type        = string
  default     = "homecloud"
  description = "Name of the homecloud domain."
}

variable "account_name" {
  type        = string
  description = "CloudStack account name (e.g. homecloud)."
}

# ── VPC ───────────────────────────────────────────────────────────────────

variable "vpc_name" {
  type        = string
  description = "Name of the VPC to create or manage."
}

variable "vpc_cidr" {
  type        = string
  description = "CIDR block for the VPC (e.g. 10.0.0.0/24)."
}

variable "vpc_offering_id" {
  type        = string
  description = "UUID of the VPC offering (from cloudstack-admin outputs)."
}

variable "vpc_networks" {
  type = map(object({
    cidr        = string
    gateway     = string
    offering_id = string
  }))
  description = "VPC network tier name → config map."
}

variable "default_acl_id" {
  type        = string
  default     = ""
  description = "UUID of the default_allow network ACL. Look up after VPC creation with cmk list networkacllists name=default_allow vpcid=<VPC_ID>."
}

variable "existing_vpc_id" {
  type        = string
  default     = ""
  description = "Existing VPC UUID for import."
}

variable "existing_network_ids" {
  type        = map(string)
  default     = {}
  description = "Map of VPC network tier key → existing network UUID for import."
}

# ── Isolated Network ─────────────────────────────────────────────────────

variable "isolated_net_name" {
  type        = string
  description = "Name of the isolated network (e.g. iso-net-shared)."
}

variable "isolated_net_cidr" {
  type        = string
  description = "CIDR block for the isolated network (e.g. 10.1.1.0/24)."
}

variable "isolated_net_gateway" {
  type        = string
  description = "Gateway IP for the isolated network."
}

variable "isolated_net_offering_id" {
  type        = string
  description = "UUID of the network offering for the isolated network (from cloudstack-admin outputs)."
}

variable "existing_isolated_net_id" {
  type        = string
  default     = ""
  description = "Existing isolated network UUID for import."
}

# ── Offering / Template IDs (from cloudstack-admin outputs) ──────────────

variable "public_lb_offering_id" {
  type        = string
  description = "UUID of the vpc.core-public-lb network offering."
}

variable "internal_lb_offering_id" {
  type        = string
  description = "UUID of the vpc.core-internal-lb network offering."
}

variable "isolated_core_offering_id" {
  type        = string
  description = "UUID of the isolated.core-redundant network offering."
}

variable "ubuntu_template_id" {
  type        = string
  description = "UUID of the Ubuntu 24.04 template (from cloudstack-admin outputs)."
}

variable "compute_offering_ids" {
  type        = map(string)
  default     = {}
  description = "Map of compute offering name → UUID (from cloudstack-admin outputs). Used to resolve offering names to UUIDs. If empty, offering names are passed directly."
}

# ── SSH Keypair ───────────────────────────────────────────────────────────

variable "keypair_name" {
  type        = string
  default     = ""
  description = "Name of the SSH keypair to register. Leave empty to skip keypair management."
}

variable "op_ssh_pub_key" {
  type        = string
  default     = ""
  description = "1Password op:// reference for the SSH public key (e.g. op://homecloud/nulcell/public key). Informational — key is read via the onepassword_item data source."
}

variable "op_ssh_pub_key_field" {
  type        = string
  default     = "public key"
  description = "Field name in the 1Password nulcell item that holds the SSH public key."
}

variable "existing_keypair_id" {
  type        = string
  default     = ""
  description = "Existing keypair name for import (CloudStack uses name as import ID)."
}

# ── User Data Scripts ─────────────────────────────────────────────────────

variable "userdata_scripts" {
  type = map(object({
    file   = string
    params = optional(list(string), [])
  }))
  default     = {}
  description = "Map of userdata name → config. Empty map = nothing registered."
}

# ── NFS Shared Filesystems ────────────────────────────────────────────────

variable "enable_shared_storage" {
  type        = bool
  default     = true
  description = "Set false to disable all shared filesystem management without removing map entries."
}

variable "shared_filesystems" {
  type = map(object({
    size_gb          = number
    service_offering = string
    disk_offering    = string
    network_name     = string
    filesystem       = optional(string, "XFS")
    provider_name    = optional(string, "SHAREDFSVM")
  }))
  default     = {}
  description = "Map of filesystem name → config. Empty map = nothing created."
}

# ── VPS VM ────────────────────────────────────────────────────────────────

variable "enable_vps" {
  type        = bool
  default     = true
  description = "Set false to skip VPS VM creation without removing the config block."
}

variable "vps" {
  type = object({
    name             = string
    compute_offering = string
    root_disk_size   = number
    network_name     = string
    userdata_name    = string
    template_name    = optional(string, "Ubuntu 24.04 - Noble")
  })
  default = {
    name             = "homecloud-vps"
    compute_offering = "gen.xlarge"
    root_disk_size   = 30
    network_name     = "priv-net-1"
    userdata_name    = "cloud-default"
    template_name    = "Ubuntu 24.04 - Noble"
  }
  description = "VPS VM configuration."
}

variable "existing_vps_id" {
  type        = string
  default     = ""
  description = "Existing VPS VM UUID for import."
}

variable "existing_userdata_ids" {
  type        = map(string)
  default     = {}
  description = "Map of userdata name → existing CloudStack UUID for import. Get with: cmk -p homecloud-admin list userdata"
}
