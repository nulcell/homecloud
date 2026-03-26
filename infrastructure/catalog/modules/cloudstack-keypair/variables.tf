variable "name" {
  type        = string
  description = "Name of the SSH keypair to register in CloudStack."
}

variable "public_key" {
  type        = string
  sensitive   = true
  description = "SSH public key string to register."
}

variable "domain_id" {
  type        = string
  description = "UUID of the CloudStack domain scoping the keypair."
}

variable "account_name" {
  type        = string
  description = "CloudStack account name the keypair is registered under."
}

variable "existing_keypair_id" {
  type        = string
  default     = ""
  description = "Existing keypair name (used as import ID) to import into state. Leave empty to register a new keypair."
}
