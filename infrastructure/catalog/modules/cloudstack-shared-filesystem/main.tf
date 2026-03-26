# ---------------------------------------------------------------------------
# Shared Filesystems (NFS-backed VMs via CloudStack SharedFileSystem API)
#
# There is no native Terraform resource for CloudStack SharedFileSystems.
# We use null_resource + cmk createSharedFileSystem.
#
# IMPORTANT: null_resource does NOT support lifecycle { prevent_destroy }.
# Removing an entry from the filesystems map WILL destroy the null_resource
# on next apply. The actual SharedFileSystem in CloudStack will NOT be
# automatically deleted (cmk deleteSharedFileSystem must be run manually),
# but the Terraform state will lose track of it.
# Use enable = false to disable all filesystems without removing map entries.
# ---------------------------------------------------------------------------
resource "null_resource" "filesystem" {
  for_each = var.enable ? var.filesystems : {}

  triggers = {
    hash = sha256(jsonencode(each.value))
  }

  provisioner "local-exec" {
    command = <<-EOT
      DISK_OFFERING_ID=$(cmk -p ${var.cmk_profile} list diskofferings \
        name='${each.value.disk_offering}' | jq -r '.diskoffering[0].id')

      NETWORK_ID=$(cmk -p ${var.cmk_profile} list networks \
        name='${each.value.network_name}' \
        account=${var.account_name} | jq -r '.network[0].id')

      SERVICE_OFFERING_ID=$(cmk -p ${var.cmk_profile} list serviceofferings \
        name='${each.value.service_offering}' | jq -r '.serviceoffering[0].id')

      cmk -p ${var.cmk_profile} createSharedFileSystem \
        name='${each.key}' \
        displaytext='${each.key}' \
        diskofferingid="$DISK_OFFERING_ID" \
        networkid="$NETWORK_ID" \
        filesystem='${each.value.filesystem}' \
        account=${var.account_name} \
        domainid=${var.domain_id} \
        zoneid=${var.zone_id} \
        serviceofferingid="$SERVICE_OFFERING_ID" \
        size=${each.value.size_gb} \
        provider='${each.value.provider_name}'
    EOT
  }
}
