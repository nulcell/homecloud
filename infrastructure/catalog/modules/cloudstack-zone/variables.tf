variable "zone_name" {
  type        = string
  description = "Name of the CloudStack zone (must already exist)."
}

variable "zone_dns1" {
  type        = string
  description = "Primary DNS for the zone."
}

variable "zone_internal_dns1" {
  type        = string
  description = "Internal primary DNS for the zone."
}

variable "zone_network_type" {
  type        = string
  description = "Network type for the zone (e.g., 'Basic' or 'Advanced')."
  # the value must be either 'Basic' or 'Advanced'
  validation {
    condition     = contains(["Basic", "Advanced"], var.zone_network_type)
    error_message = "zone_network_type must be either 'Basic' or 'Advanced'."
  }
}

variable "physical_networks" {
  type = map(object({
    isolation_method = string
    traffic_types    = list(string)
    network_speed    = optional(string, "10G")
    tags             = optional(string)
    vlan_range       = optional(string)
    kvm_labels       = optional(map(string), {})
    service_providers = optional(list(object({
      name         = string
      service_list = optional(list(string))
    })), [])
    public_ip_range = optional(object({
      gateway  = string
      netmask  = string
      start_ip = string
      end_ip   = string
      vlan     = string
    }))
  }))
  description = "Map of physical network name → configuration."
}

variable "pod" {
  type = object({
    name     = string
    gateway  = string
    netmask  = string
    start_ip = string
    end_ip   = string
  })
  description = "Pod configuration for the zone."
}

variable "cluster" {
  type = object({
    name       = string
    hypervisor = string
  })
  description = "KVM cluster configuration."
}

variable "hosts" {
  type = map(object({
    username = string
  }))
  description = "Map of host IP address → host configuration."
}

variable "primary_storage_pools" {
  type = map(object({
    server = string
    path   = string
  }))
  description = "Map of primary storage pool name → NFS configuration."
}

variable "secondary_storage" {
  type = map(object({
    server = string
    path   = string
  }))
  description = "Map of secondary storage (image store) name → NFS configuration."
}

variable "cmk_profile" {
  type        = string
  default     = "admin"
  description = "Cloudmonkey profile name for host provisioning (no native resource)."
}

variable "existing_pod_id" {
  type        = string
  default     = ""
  description = "Existing pod UUID for import. Leave empty to create."
}

variable "existing_cluster_id" {
  type        = string
  default     = ""
  description = "Existing cluster UUID for import. Leave empty to create."
}

variable "existing_physical_network_ids" {
  type        = map(string)
  default     = {}
  description = "Map of physical network name → UUID for import."
}

variable "existing_traffic_type_ids" {
  type        = map(string)
  default     = {}
  description = "Map of '<net>/<type>' → UUID for traffic type import."
}

variable "existing_nsp_ids" {
  type        = map(string)
  default     = {}
  description = "Map of '<net>/<provider>' → UUID for network service provider import."
}

variable "existing_vlan_ip_range_ids" {
  type        = map(string)
  default     = {}
  description = "Map of physical network name → VLAN IP range UUID for import."
}

variable "existing_storage_pool_ids" {
  type        = map(string)
  default     = {}
  description = "Map of storage pool name → UUID for primary storage import."
}

variable "existing_secondary_storage_ids" {
  type        = map(string)
  default     = {}
  description = "Map of image store name → UUID for secondary storage import."
}
