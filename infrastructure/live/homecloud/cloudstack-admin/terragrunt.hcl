# cloudstack-admin unit
# Admin-scope CloudStack resources (cloudstack.admin provider ONLY).
# This is the only live unit that runs with CloudStack root admin credentials.
#
# Manages:
#   - Global configuration settings (~30 settings, idempotent cloudstack_configuration)
#   - Zone + physical networks + pod + KVM cluster + hosts + storage pools  (all IMPORTED)
#   - Domain creation (homecloud) + resource limits                          (IMPORTED)
#   - Account creation (homecloud/homecloud-admin)                           (IMPORTED)
#   - All offerings: disk, compute, network, VPC — as input maps (for_each)  (IMPORTED)
#   - Templates/images: Ubuntu 24.04, Talos raw image — as input map         (IMPORTED/REGISTERED)
#     Images use lifecycle { prevent_destroy = true } — never deleted even if removed from input
#
# NOT here (homecloud domain scope → cloudstack-homecloud unit):
#   VPC, networks, isolated network, SSH keypair, userdata, NFS filesystems

include "root" {
  path = find_in_parent_folders("root.hcl")
}

include "account" {
  path   = find_in_parent_folders("account.hcl")
  expose = true
}

terraform {
  source = "${get_repo_root()}//infrastructure/catalog/stacks/cloudstack-admin"
}

inputs = {
  cloudstack_api_url = include.account.locals.cloudstack_api_url
  op_vault           = include.account.locals.op_vault
  zone_name          = include.account.locals.zone_name

  # ── Domain / Account ──────────────────────────────────────────────────────
  domain_name    = "homecloud"
  domain_network = include.account.locals.network_domain
  account_name   = "homecloud"
  timezone       = "Europe/Amsterdam"

  # ── Disk Offerings (map: name → config) ──────────────────────────────────
  disk_offerings = {
    "shared.custom" = { display_text = "Shared Storage Custom Size Disk", storage_type = "shared", customized = true }
    "local.custom"  = { display_text = "Local Storage Custom Size Disk",  storage_type = "local",  customized = true }
    "shared.small"  = { display_text = "Shared Storage Small Disk",  storage_type = "shared", disk_size = 30 }
    "shared.medium" = { display_text = "Shared Storage Medium Disk", storage_type = "shared", disk_size = 50 }
    "shared.large"  = { display_text = "Shared Storage Large Disk",  storage_type = "shared", disk_size = 100 }
    "shared.xlarge" = { display_text = "Shared Storage XLarge Disk", storage_type = "shared", disk_size = 200 }
    "local.small"   = { display_text = "Local Storage Small Disk",  storage_type = "local", disk_size = 30 }
    "local.medium"  = { display_text = "Local Storage Medium Disk", storage_type = "local", disk_size = 50 }
    "local.large"   = { display_text = "Local Storage Large Disk",  storage_type = "local", disk_size = 100 }
    "local.xlarge"  = { display_text = "Local Storage XLarge Disk", storage_type = "local", disk_size = 200 }
  }

  # ── Compute Offerings (map: name → config) ────────────────────────────────
  compute_offerings = {
    "gen.tiny"     = { display_text = "General Purpose Tiny",    cpu_number = 1,  cpu_speed = 1000, memory = 512,   root_disk_size = 5  }
    "gen.small"    = { display_text = "General Purpose Small",   cpu_number = 1,  cpu_speed = 2500, memory = 1024,  root_disk_size = 10 }
    "gen.medium"   = { display_text = "General Purpose Medium",  cpu_number = 2,  cpu_speed = 2500, memory = 2048,  root_disk_size = 20 }
    "gen.large"    = { display_text = "General Purpose Large",   cpu_number = 4,  cpu_speed = 2500, memory = 4096,  root_disk_size = 30 }
    "gen.xlarge"   = { display_text = "General Purpose xLarge",  cpu_number = 8,  cpu_speed = 2500, memory = 8192,  root_disk_size = 50 }
    "gen.1xlarge"  = { display_text = "General Purpose 1xLarge", cpu_number = 12, cpu_speed = 2500, memory = 12288, root_disk_size = 60 }
    "gen.2xlarge"  = { display_text = "General Purpose 2xLarge", cpu_number = 16, cpu_speed = 2500, memory = 16384, root_disk_size = 75 }
    "mem.tiny"     = { display_text = "Memory Optimized Tiny",   cpu_number = 1,  cpu_speed = 1000, memory = 1024,  root_disk_size = 5  }
    "mem.small"    = { display_text = "Memory Optimized Small",  cpu_number = 1,  cpu_speed = 2500, memory = 2048,  root_disk_size = 10 }
    "mem.medium"   = { display_text = "Memory Optimized Medium", cpu_number = 2,  cpu_speed = 2500, memory = 4096,  root_disk_size = 20 }
    "mem.large"    = { display_text = "Memory Optimized Large",  cpu_number = 4,  cpu_speed = 2500, memory = 8192,  root_disk_size = 30 }
    "mem.xlarge"   = { display_text = "Memory Optimized xLarge", cpu_number = 8,  cpu_speed = 2500, memory = 16384, root_disk_size = 50 }
    "mem.1xlarge"  = { display_text = "Memory Optimized 1xLarge",cpu_number = 12, cpu_speed = 2500, memory = 24576, root_disk_size = 60 }
    "mem.2xlarge"  = { display_text = "Memory Optimized 2xLarge",cpu_number = 16, cpu_speed = 2500, memory = 32768, root_disk_size = 75 }
  }

  # ── Templates / Images (map: key → config; lifecycle prevent_destroy) ────
  # Images are NEVER deleted even if removed from this map (prevent_destroy).
  # To decommission an image, first remove VMs using it, then manually delete.
  templates = {
    "ubuntu-24.04" = {
      name        = "Ubuntu 24.04 - Noble"
      display_text = "Ubuntu 24.04 LTS (Noble Numbat) x86_64"
      url         = "https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img"
      format      = "qcow2"
      hypervisor  = "KVM"
      os_type     = "Ubuntu 24.04"
      is_featured = true
    }
    "talos-v1.12.6" = {
      name        = "Talos v1.12.6 - CloudStack"
      display_text = "Talos Linux v1.12.6 for CloudStack (btrfs, nfs, qemu-guest-agent)"
      # Schematic: 23ff67af89fd08e5703f919f9b58c5a4a6de2540b1f8ca83379e19321560b1bf
      # Extensions: btrfs, nfs-utils, nfsd, nfsrahead, qemu-guest-agent
      # NOTE: Try dropping .gz if CloudStack rejects the compressed image
      url         = "https://factory.talos.dev/image/23ff67af89fd08e5703f919f9b58c5a4a6de2540b1f8ca83379e19321560b1bf/v1.12.6/cloudstack-amd64.raw.gz"
      format      = "RAW"
      hypervisor  = "KVM"
      os_type     = "Other (64-bit)"
      is_featured = false
    }
  }
}
