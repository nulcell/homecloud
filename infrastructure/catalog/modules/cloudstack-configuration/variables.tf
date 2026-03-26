variable "global_settings" {
  type        = map(string)
  description = "Map of CloudStack configuration key → value to apply via updateConfiguration API."
}

variable "cmk_profile" {
  type        = string
  default     = "admin"
  description = "Cloudmonkey profile name with admin credentials."
}
