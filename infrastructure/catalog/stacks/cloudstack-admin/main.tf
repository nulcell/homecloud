# ---------------------------------------------------------------------------
# Import blocks (root module only — Terraform 1.14+ restriction)
#
# Populate existing_* variables in your terragrunt.hcl inputs map with the
# CloudStack UUIDs before running `terragrunt plan`. Commands to look up IDs:
#
#   Zone / infrastructure:
#     cmk -p admin list zones --output text --filter id,name
#     cmk -p admin list physicalnetworks zoneid=<z> --output text --filter id,name
#     cmk -p admin list pods zoneid=<z> --output text --filter id,name
#     cmk -p admin list clusters zoneid=<z> --output text --filter id,name
#     cmk -p admin list storagepools zoneid=<z> --output text --filter id,name
#     cmk -p admin list imageStores zoneid=<z>
#     cmk -p admin list traffictypes physicalnetworkid=<p>
#     cmk -p admin list networkserviceproviders physicalnetworkid=<p>
#     cmk -p admin list vlanipranges zoneid=<z>
#
#   Domain / account:
#     cmk -p admin list domains name=homecloud --output text --filter id
#     cmk -p admin list accounts name=homecloud domainid=<d> --output text --filter id
#
#   Offerings:
#     cmk -p admin list diskofferings --output text --filter id,name
#     cmk -p admin list serviceofferings --output text --filter id,name
#     cmk -p admin list networkofferings --output text --filter id,name
#
#   Templates:
#     cmk -p admin list templates templatefilter=all --output text --filter id,name
# ---------------------------------------------------------------------------

# ── Physical networks ──────────────────────────────────────────────────────
import {
  for_each = { for k, v in var.existing_physical_network_ids : k => v if v != "" }
  to       = module.zone.cloudstack_physical_network.this[each.key]
  id       = each.value
}

# ── Traffic types ──────────────────────────────────────────────────────────
import {
  for_each = { for k, v in var.existing_traffic_type_ids : k => v if v != "" }
  to       = module.zone.cloudstack_traffic_type.this[each.key]
  id       = each.value
}

# ── Network service providers ──────────────────────────────────────────────
import {
  for_each = { for k, v in var.existing_nsp_ids : k => v if v != "" }
  to       = module.zone.cloudstack_network_service_provider.this[each.key]
  id       = each.value
}

# ── VLAN IP ranges ─────────────────────────────────────────────────────────
import {
  for_each = { for k, v in var.existing_vlan_ip_range_ids : k => v if v != "" }
  to       = module.zone.cloudstack_vlan_ip_range.this[each.key]
  id       = each.value
}

# ── Pod ────────────────────────────────────────────────────────────────────
import {
  for_each = var.existing_pod_id != "" ? { this = var.existing_pod_id } : {}
  to       = module.zone.cloudstack_pod.this
  id       = each.value
}

# ── Cluster ────────────────────────────────────────────────────────────────
import {
  for_each = var.existing_cluster_id != "" ? { this = var.existing_cluster_id } : {}
  to       = module.zone.cloudstack_cluster.this
  id       = each.value
}

# ── Primary storage pools ──────────────────────────────────────────────────
import {
  for_each = { for k, v in var.existing_storage_pool_ids : k => v if v != "" }
  to       = module.zone.cloudstack_storage_pool.primary[each.key]
  id       = each.value
}

# ── Secondary storage ──────────────────────────────────────────────────────
import {
  for_each = { for k, v in var.existing_secondary_storage_ids : k => v if v != "" }
  to       = module.zone.cloudstack_secondary_storage.this[each.key]
  id       = each.value
}

# ── Domain ─────────────────────────────────────────────────────────────────
# NOTE: cloudstack_domain does not support import in provider v0.6.
# On a fresh install this creates the domain; on existing infra it will
# show as "to create" but the apply will fail gracefully (domain already exists).

# ── Account ────────────────────────────────────────────────────────────────
# NOTE: cloudstack_account does not support import in provider v0.6.

# ── Disk offerings (fixed size) ────────────────────────────────────────────
# NOTE: cloudstack_disk_offering does not support import in provider v0.6.
# Existing offerings are managed idempotently; TF will show them as "to create".

# ── Compute offerings ─────────────────────────────────────────────────────
# NOTE: cloudstack_service_offering_* resources do not support import in provider v0.6.
# Existing offerings are managed idempotently; TF will show them as "to create".

# ── Network offerings ──────────────────────────────────────────────────────
# NOTE: cloudstack_network_offering does not support import in provider v0.6.
# Managed via null_resource + cmk with idempotent existence check (below).

# ── Templates ──────────────────────────────────────────────────────────────
# NOTE: cloudstack_template does not support import in provider v0.6.
# Existing templates are managed idempotently; TF will show them as "to create".
# Read homecloud account credentials from 1Password.
# Used by module.account to provision the domain-scoped admin user.
# Store this item with a section containing fields labelled:
#   "email", "First name", "Last name", "username", "password"
data "onepassword_item" "cs_homecloud_creds" {
  vault = var.op_vault
  title = var.op_cs_homecloud_item
}

locals {
  _cs_homecloud_fields = merge(
    # Standard Login fields (username / password)
    {
      username = try(data.onepassword_item.cs_homecloud_creds.username, "")
      password = try(data.onepassword_item.cs_homecloud_creds.password, "")
    },
    # Any section fields (email, First name, Last name, etc.)
    merge([
      for s in data.onepassword_item.cs_homecloud_creds.section : {
        for f in s.field : f.label => f.value
      }
    ]...)
  )
}

# ── Global configuration ──────────────────────────────────────────────────────
module "configuration" {
  source = "../../modules/cloudstack-configuration"

  global_settings = var.global_settings
  cmk_profile     = "admin"
}

# ── Zone infrastructure ───────────────────────────────────────────────────────
module "zone" {
  source = "../../modules/cloudstack-zone"

  zone_name             = var.zone_name
  physical_networks     = var.physical_networks
  pod                   = var.pod
  cluster               = var.cluster
  hosts                 = var.hosts
  primary_storage_pools = var.primary_storage_pools
  secondary_storage     = var.secondary_storage
  cmk_profile           = "admin"

  existing_pod_id                = var.existing_pod_id
  existing_cluster_id            = var.existing_cluster_id
  existing_physical_network_ids  = var.existing_physical_network_ids
  existing_traffic_type_ids      = var.existing_traffic_type_ids
  existing_nsp_ids               = var.existing_nsp_ids
  existing_vlan_ip_range_ids     = var.existing_vlan_ip_range_ids
  existing_storage_pool_ids      = var.existing_storage_pool_ids
  existing_secondary_storage_ids = var.existing_secondary_storage_ids
}

# ── Domain ────────────────────────────────────────────────────────────────────
module "domain" {
  count  = var.enable_domain ? 1 : 0
  source = "../../modules/cloudstack-domain"

  domain_name        = var.domain_name
  domain_network     = var.domain_network
  account_name       = var.account_name
  resource_limits    = var.resource_limits
  existing_domain_id = var.existing_domain_id
}

# ── Account ───────────────────────────────────────────────────────────────────
module "account" {
  count  = var.enable_account ? 1 : 0
  source = "../../modules/cloudstack-account"

  account_name        = var.account_name
  account_type        = 2 # domain admin
  domain_id           = var.enable_domain ? module.domain[0].domain_id : var.existing_domain_id
  email               = local._cs_homecloud_fields["Email"]
  firstname           = local._cs_homecloud_fields["First name"]
  lastname            = local._cs_homecloud_fields["Last name"]
  password            = data.onepassword_item.cs_homecloud_creds.password
  username            = data.onepassword_item.cs_homecloud_creds.username
  existing_account_id = var.existing_account_id
}

# ── Offerings ─────────────────────────────────────────────────────────────────
module "offerings" {
  source = "../../modules/cloudstack-offerings"

  cmk_profile              = "admin"
  disk_offerings           = var.disk_offerings
  compute_offerings        = var.compute_offerings
  network_offerings        = var.network_offerings
  vpc_offerings            = var.vpc_offerings
  custom_disk_offering_ids = var.custom_disk_offering_ids

  existing_disk_offering_ids    = var.existing_disk_offering_ids
  existing_compute_offering_ids = var.existing_compute_offering_ids
  existing_network_offering_ids = var.existing_network_offering_ids
  existing_vpc_offering_ids     = var.existing_vpc_offering_ids
}

# ── Templates / ISOs ──────────────────────────────────────────────────────────
module "templates" {
  source = "../../modules/cloudstack-templates"

  zone_id   = module.zone.zone_id
  zone_name = var.zone_name
  templates = var.templates
  isos      = var.isos

  existing_template_ids = var.existing_template_ids
}

