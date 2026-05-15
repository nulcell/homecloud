variable "description" {
  type        = string
  default     = "homecloud-vpn-router"
  description = "Human-readable description for the auth key."
}

variable "reusable" {
  type        = bool
  default     = false
  description = "Whether the auth key can be used more than once."
}

variable "ephemeral" {
  type        = bool
  default     = false
  description = "Whether devices that use this key are marked ephemeral."
}

variable "tags" {
  type        = list(string)
  default     = ["tag:subnet-router"]
  description = "ACL tags to apply to devices that authenticate with this key."
}

variable "expiry_seconds" {
  type        = number
  default     = 3600
  description = "Key expiry in seconds from creation."
}
