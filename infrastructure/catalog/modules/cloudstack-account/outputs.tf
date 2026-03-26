output "account_id" {
  description = "UUID of the CloudStack account."
  value       = cloudstack_account.this.id
}

output "account_name" {
  description = "Name of the CloudStack account."
  value       = cloudstack_account.this.account
}

output "domain_id" {
  description = "UUID of the CloudStack domain the account belongs to."
  value       = cloudstack_account.this.domain_id
}
