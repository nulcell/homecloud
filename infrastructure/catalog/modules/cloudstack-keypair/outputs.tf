output "keypair_name" {
  description = "Name of the registered SSH keypair."
  value       = cloudstack_ssh_keypair.this.name
}

output "fingerprint" {
  description = "MD5 fingerprint of the registered SSH public key."
  value       = cloudstack_ssh_keypair.this.fingerprint
}
