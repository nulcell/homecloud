# ---------------------------------------------------------------------------
# Disk Offerings — fixed size
# cloudstack_disk_offering only supports name/display_text/disk_size.
# Customised disk offerings (shared.custom, local.custom) are created via
# null_resource below since the TF provider lacks customized=true support.
# Import: populate existing_disk_offering_ids map with name → UUID.
#   cmk -p admin list diskofferings --output text --filter id,name
# ---------------------------------------------------------------------------

resource "cloudstack_disk_offering" "fixed" {
  for_each = { for k, v in var.disk_offerings : k => v if !v.customized }

  name         = each.key
  display_text = each.value.display_text
  disk_size    = each.value.disk_size
}

# Customised disk offerings (user picks size at deploy time). The provider
# does not expose the `customized=true storagetype=...` parameters, so we
# use cloudmonkey with an idempotent existence check.
resource "null_resource" "custom_disk_offering" {
  for_each = { for k, v in var.disk_offerings : k => v if v.customized }

  triggers = {
    name         = each.key
    display_text = each.value.display_text
    storage_type = each.value.storage_type
  }

  provisioner "local-exec" {
    command = <<-EOT
      EXISTING=$(cmk -p ${var.cmk_profile} list diskofferings name='${each.key}' \
        --output text --filter id 2>/dev/null | head -1)
      if [ -z "$EXISTING" ]; then
        cmk -p ${var.cmk_profile} create diskoffering \
          name='${each.key}' \
          displaytext='${each.value.display_text}' \
          customized=true \
          storagetype='${each.value.storage_type}'
      else
        echo "Disk offering '${each.key}' already exists ($EXISTING), skipping."
      fi
    EOT
  }
}

# ---------------------------------------------------------------------------
# Compute Offerings — fixed (baked-in CPU/RAM, storage via disk_offering block)
#   disk_type = "fixed": e.g. gen.*.fixed, mem.*.fixed, ssd.*
# ---------------------------------------------------------------------------
locals {
  fixed_compute = {
    for k, v in var.compute_offerings : k => v
    if v.disk_type == "fixed"
  }
  unconstrained_compute = {
    for k, v in var.compute_offerings : k => v
    if contains(["custom_shared", "custom_local"], v.disk_type)
  }
  constrained_compute = {
    for k, v in var.compute_offerings : k => v
    if v.disk_type == "customized"
  }
}

resource "cloudstack_service_offering_fixed" "this" {
  for_each = local.fixed_compute

  name         = each.key
  display_text = each.value.display_text
  cpu_number   = each.value.cpu_number
  cpu_speed    = each.value.cpu_speed
  memory       = each.value.memory
  network_rate = each.value.network_rate
  offer_ha     = each.value.offer_ha

  disk_offering = {
    cache_mode               = "none"
    disk_offering_strictness = false
    provisioning_type        = "thin"
    storage_type             = each.value.storage_type
    root_disk_size           = each.value.root_disk_size
  }
}

# ---------------------------------------------------------------------------
# Compute Offerings — unconstrained (custom CPU/RAM, disk offered separately)
#   disk_type = "custom_shared" | "custom_local"
#   e.g. gen.tiny, mem.small, gen.xlarge (without .fixed suffix)
# ---------------------------------------------------------------------------

resource "cloudstack_service_offering_unconstrained" "this" {
  for_each = local.unconstrained_compute

  name         = each.key
  display_text = each.value.display_text
  network_rate = each.value.network_rate
  offer_ha     = each.value.offer_ha

  # disk_offering_id must be the CloudStack UUID of the custom disk offering.
  # After the first apply, look up UUIDs with:
  #   cmk -p admin list diskofferings name="shared.custom" --output text --filter id
  # Then pass them via existing_compute_offering_ids or set directly in the live unit.
  disk_offering_id        = (
    each.value.disk_type == "custom_shared"
    ? lookup(var.custom_disk_offering_ids, "shared.custom", null)
    : lookup(var.custom_disk_offering_ids, "local.custom", null)
  )
  dynamic_scaling_enabled = true

  depends_on = [null_resource.custom_disk_offering]
}

# ---------------------------------------------------------------------------
# Compute Offerings — constrained (min/max CPU and memory bounds)
#   disk_type = "customized": e.g. custom.shared, custom.local
# ---------------------------------------------------------------------------

resource "cloudstack_service_offering_constrained" "this" {
  for_each = local.constrained_compute

  name           = each.key
  display_text   = each.value.display_text
  cpu_speed      = each.value.cpu_speed
  min_cpu_number = each.value.min_cpu
  max_cpu_number = each.value.max_cpu
  min_memory     = each.value.min_memory
  max_memory     = each.value.max_memory
  network_rate   = each.value.network_rate
  offer_ha       = each.value.offer_ha

  disk_offering = {
    disk_offering_strictness = true
    cache_mode               = "none"
    provisioning_type        = "thin"
    storage_type             = each.value.storage_type
  }
}

# ---------------------------------------------------------------------------
# Network Offerings
# Import: populate existing_network_offering_ids map with name → UUID.
#   cmk -p admin list networkofferings --output text --filter id,name
# ---------------------------------------------------------------------------

resource "cloudstack_network_offering" "network" {
  for_each = var.network_offerings

  name          = each.key
  display_text  = each.value.display_text
  guest_ip_type = each.value.guest_ip_type
  traffic_type  = "Guest"
  for_vpc       = each.value.for_vpc
  specify_vlan  = each.value.specify_vlan
  conserve_mode = true
  enable        = true

  supported_services = each.value.services
  service_provider_list = {
    for svc in each.value.services : svc => (
      svc == "Lb" && each.value.lb_provider != null
      ? each.value.lb_provider
      : each.value.for_vpc ? "VpcVirtualRouter" : "VirtualRouter"
    )
  }
}

# ---------------------------------------------------------------------------
# VPC Offerings — no cloudstack_vpc_offering resource in provider v0.6.
# Use null_resource + cmk with idempotent existence check.
# Import: existing VPC offerings are left unmanaged (cmk createVPCOffering
# is not re-run if the offering already exists).
# ---------------------------------------------------------------------------
resource "null_resource" "vpc_offering" {
  for_each = var.vpc_offerings

  triggers = {
    name         = each.key
    display_text = each.value.display_text
    services     = join(",", sort(each.value.services))
  }

  provisioner "local-exec" {
    command = <<-EOT
      EXISTING=$(cmk -p ${var.cmk_profile} list vpcofferings name='${each.key}' \
        --output text --filter id 2>/dev/null | head -1)
      if [ -z "$EXISTING" ]; then
        cmk -p ${var.cmk_profile} createVPCOffering \
          name='${each.key}' \
          displaytext='${each.value.display_text}' \
          supportedservices='${join(",", each.value.services)}'
      else
        echo "VPC offering '${each.key}' already exists ($EXISTING), skipping."
      fi
    EOT
  }
}
