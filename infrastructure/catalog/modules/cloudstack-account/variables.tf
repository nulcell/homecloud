variable "account_name" {
  type        = string
  description = "CloudStack account name."
}

variable "account_type" {
  type        = number
  default     = 2
  description = "Account type: 0 = user, 1 = root admin, 2 = domain admin."
}

variable "domain_id" {
  type        = string
  description = "UUID of the CloudStack domain in which to create the account."
}

variable "email" {
  type        = string
  description = "Email address for the account's admin user."
}

variable "firstname" {
  type        = string
  description = "First name of the account's admin user."
}

variable "lastname" {
  type        = string
  description = "Last name of the account's admin user."
}

variable "password" {
  type        = string
  sensitive   = true
  description = "Password for the account's admin user."
}

variable "username" {
  type        = string
  description = "Username for the account's admin user."
}

variable "role_id" {
  type        = string
  default     = ""
  description = "Role UUID to assign. Leave empty to auto-resolve the default role for the given account_type."
}

variable "existing_account_id" {
  type        = string
  default     = ""
  description = "Existing account UUID for import. Leave empty to create a new account."
}
