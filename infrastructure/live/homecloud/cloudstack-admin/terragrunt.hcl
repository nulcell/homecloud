# cloudstack-admin unit
# Admin-scope CloudStack resources (cloudstack.admin provider ONLY).
# This is the only live unit that runs with CloudStack root admin credentials.
#
# Optionality:
#   - for_each maps: empty map = nothing created; remove entry = resource deleted (except templates)
#   - Templates/images: lifecycle { prevent_destroy = true } — NEVER auto-deleted
#   - kubernetes_versions map: optional (enable_cks = true since they exist live)
#   - Zone infrastructure (physical_networks, pod, cluster, hosts, storage): set-once, all IMPORTED
#
# Manages (all IMPORTED unless noted):
#   - ~30 Global configuration settings
#   - Zone (zone-homecloud) + 2 physical networks + pod + cluster + 2 hosts
#   - 2 primary storage pools + 2 secondary storage (image stores)
#   - Domain (homecloud) + account (homecloud) + 17 resource limits
#   - Disk offerings (10), compute offerings (37), network offerings (6), VPC offerings (2)
#   - Templates: Ubuntu 24.04, Debian 12, Talos v1.12.6     — prevent_destroy
#   - ISOs: Windows Server 2025, VirtIO drivers              — prevent_destroy, optional
#   - CKS Kubernetes supported versions (4)                  — optional, enable_cks = true
#
# NOT here (homecloud domain scope → cloudstack-homecloud unit):
#   VPC, networks, isolated network, SSH keypair, userdata, NFS filesystems, VMs

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
  op_account         = include.account.locals.op_account
  zone_name          = include.account.locals.zone_name

  # ── Global Settings (map: config_name → value) ───────────────────────────
  global_settings = {
    # Access
    "metadata.allow.expose.domain"                                         = "true"
    # Compute – VM
    "cluster.cpu.allocated.capacity.disablethreshold"                      = "1"
    "cluster.cpu.allocated.capacity.notificationthreshold"                 = "1"
    "enable.additional.vm.configuration"                                   = "true"
    "enable.dynamic.scale.vm"                                              = "true"
    "instance.lease.enabled"                                               = "true"
    "system.vm.default.hypervisor"                                         = "KVM"
    "vm.allocation.algorithm"                                              = "userdispersing"
    "vm.deployment.planner"                                                = "UserDispersingPlanner"
    "vm.destroy.forcestop"                                                 = "true"
    "vm.display.ovf.properties"                                            = "true"
    "vm.password.length"                                                   = "12"
    "vm.userdata.max.length"                                               = "1048576"
    "cpu.overprovisioning.factor"                                          = "1.25"
    "vm.min.cpu.speed.equals.cpu.speed.divided.by.cpu.overprovisioning.factor" = "false"
    "vm.min.memory.equals.memory.divided.by.mem.overprovisioning.factor"  = "false"
    "vm.serviceoffering.cpu.cores.max"                                     = "16"
    "vm.serviceoffering.ram.size.max"                                      = "32768"
    "user.vm.readonly.details"                                             = ""
    "user.vm.denied.details"                                               = "cpuOvercommitRatio,memoryOvercommitRatio"
    # Storage
    "destroy.root.volume.on.vm.destruction"                                = "true"
    "snapshot.delta.max"                                                   = "32"
    "storage.overprovisioning.factor"                                      = "2"
    # Network
    "network.throttling.rate"                                              = "500"
    "vpc.max.networks"                                                     = "4"
    "vpc.tier.name.prepend"                                                = "true"
    "vpc.tier.name.prepend.delimiter"                                      = "_"
    "cloud.dns.name"                                                       = "homecloud.internal"
    "guest.domain.suffix"                                                  = "homecloud.internal"
    # Hypervisor – KVM
    "enable.kvm.host.auto.enable.disable"                                  = "true"
    "kvm.incremental.snapshot"                                             = "true"
    # API
    "enable.ec2.api"                                                       = "true"
    "enable.s3.api"                                                        = "true"
    # Console
    "consoleproxy.sslEnabled"                                              = "true"
    # Miscellaneous
    "endpoint.url"                                                         = "http://10.10.17.5:8080/client/api"
    "store.download.follow.redirects"                                      = "true"
    "mem.overprovisioning.factor"                                          = "1.25"
  }

  # ── Zone Infrastructure (all IMPORTED, set-once) ──────────────────────────
  zone = {
    dns1                         = "10.10.31.254"
    dns2                         = "8.8.8.8"
    internal_dns1                = "10.10.31.254"
    guest_cidr                   = "10.0.0.0/24"
    network_domain               = "homecloud.internal"
    local_storage_enabled        = true
    local_storage_enabled_for_system_vm = false
  }

  # Two physical networks: cloudbr0 (Management) and cloudbr1 (Public + Guest)
  physical_networks = {
    "cloudbr0" = {
      isolation_method = "VLAN"
      traffic_types    = ["Management"]
      vlan_range       = null
      public_ip_range  = null
    }
    "cloudbr1" = {
      isolation_method = "VLAN"
      traffic_types    = ["Public", "Guest"]
      vlan_range       = "500-700"
      public_ip_range = {
        gateway  = "10.10.31.254"
        netmask  = "255.255.240.0"
        start_ip = "10.10.20.1"
        end_ip   = "10.10.20.254"
        vlan     = "vlan://untagged"
      }
    }
  }

  pod = {
    name     = "pod-homecloud"
    gateway  = "10.10.31.254"
    netmask  = "255.255.240.0"
    start_ip = "10.10.21.1"
    end_ip   = "10.10.21.254"
  }

  cluster = {
    name       = "cluster-homecloud"
    hypervisor = "KVM"
  }

  # map: ip_address → { username }
  hosts = {
    "10.10.17.5"  = { username = "root" }
    "10.10.17.10" = { username = "root" }
  }

  # map: name → { server, path }  (zone-wide NFS primary storage)
  primary_storage_pools = {
    "primary-nfs-zone-homecloud"  = { server = "10.10.17.10", path = "/export/primary" }
    "primary-nfs2-zone-homecloud" = { server = "10.10.17.5",  path = "/export/primary" }
  }

  # map: name → { server, path }  (NFS image stores — null_resource, no native TF resource)
  secondary_storage = {
    "secondary-nfs-zone-homecloud"  = { server = "10.10.17.10", path = "/export/secondary" }
    "secondary-nfs2-zone-homecloud" = { server = "10.10.17.5",  path = "/export/secondary" }
  }

  # ── Domain / Account ──────────────────────────────────────────────────────
  domain_name    = "homecloud"
  domain_network = include.account.locals.network_domain
  account_name   = "homecloud"
  timezone       = "Europe/Amsterdam"

  # Resource limits: map of resourcetype (int as string) → max value
  # 0=Instances 1=IPs 2=Volumes 3=Snapshots 4=Templates 5=Projects
  # 6=Networks 7=VPCs 8=CPUs 9=Memory(MiB) 10=PrimaryStorage(GiB)
  # 11=SecondaryStorage(GiB) 12=Backups 13=BackupStorage(GiB) 14=Buckets
  # 15=ObjectStorage(GiB) 16=GPUs
  resource_limits = {
    "0"  = 40
    "1"  = 40
    "2"  = 100
    "3"  = 100
    "4"  = 40
    "5"  = 5
    "6"  = 20
    "7"  = 4
    "8"  = 110
    "9"  = 148480
    "10" = 2000
    "11" = 2000
    "12" = 50
    "13" = 1000
    "14" = 0
    "15" = 0
    "16" = 2
  }

  # ── Disk Offerings (map: name → config) ──────────────────────────────────
  disk_offerings = {
    "shared.custom" = { display_text = "Shared Storage Custom Size Disk", storage_type = "shared", customized = true }
    "local.custom"  = { display_text = "Local Storage Custom Size Disk",  storage_type = "local",  customized = true }
    "shared.small"  = { display_text = "Shared Storage Small Disk",   storage_type = "shared", disk_size = 30 }
    "shared.medium" = { display_text = "Shared Storage Medium Disk",  storage_type = "shared", disk_size = 50 }
    "shared.large"  = { display_text = "Shared Storage Large Disk",   storage_type = "shared", disk_size = 100 }
    "shared.xlarge" = { display_text = "Shared Storage XLarge Disk",  storage_type = "shared", disk_size = 200 }
    "local.small"   = { display_text = "Local Storage Small Disk",    storage_type = "local",  disk_size = 30 }
    "local.medium"  = { display_text = "Local Storage Medium Disk",   storage_type = "local",  disk_size = 50 }
    "local.large"   = { display_text = "Local Storage Large Disk",    storage_type = "local",  disk_size = 100 }
    "local.xlarge"  = { display_text = "Local Storage XLarge Disk",   storage_type = "local",  disk_size = 200 }
  }

  # ── Compute Offerings ─────────────────────────────────────────────────────
  # disk_type:
  #   "custom_shared" → disk_offering = shared.custom  (dynamic scaling enabled)
  #   "custom_local"  → disk_offering = local.custom   (ssd family, ha = false)
  #   "fixed"         → storage_type + root_disk_size baked in (dynamic scaling disabled)
  #   "customized"    → fully custom CPU+RAM+disk (custom.* offerings)
  compute_offerings = {
    # ── gen family – custom shared disk ────────────────────────────────────
    "gen.tiny"     = { display_text = "General Purpose Tiny with Custom Disk",       cpu_number = 1,  cpu_speed = 1000, memory = 512,   network_rate = 500,  offer_ha = true,  disk_type = "custom_shared" }
    "gen.small"    = { display_text = "General Purpose Small with Custom Disk",      cpu_number = 1,  cpu_speed = 2500, memory = 1024,  network_rate = 750,  offer_ha = true,  disk_type = "custom_shared" }
    "gen.medium"   = { display_text = "General Purpose Medium with Custom Disk",     cpu_number = 2,  cpu_speed = 2500, memory = 2048,  network_rate = 750,  offer_ha = true,  disk_type = "custom_shared" }
    "gen.large"    = { display_text = "General Purpose Large with Custom Disk",      cpu_number = 4,  cpu_speed = 2500, memory = 4096,  network_rate = 1024, offer_ha = true,  disk_type = "custom_shared" }
    "gen.xlarge"   = { display_text = "General Purpose xLarge with Custom Disk",     cpu_number = 8,  cpu_speed = 2500, memory = 8192,  network_rate = 1024, offer_ha = true,  disk_type = "custom_shared" }
    "gen.1xlarge"  = { display_text = "General Purpose 1.5xLarge with Custom Disk",  cpu_number = 12, cpu_speed = 2500, memory = 12288, network_rate = 1024, offer_ha = true,  disk_type = "custom_shared" }
    "gen.2xlarge"  = { display_text = "General Purpose 2xLarge with Custom Disk",    cpu_number = 16, cpu_speed = 2500, memory = 16384, network_rate = 1024, offer_ha = true,  disk_type = "custom_shared" }
    # ── gen family – fixed disk ────────────────────────────────────────────
    "gen.small.fixed"   = { display_text = "General Purpose Small",   cpu_number = 1,  cpu_speed = 2500, memory = 1024,  network_rate = 750,  offer_ha = true,  disk_type = "fixed", root_disk_size = 10, storage_type = "shared" }
    "gen.medium.fixed"  = { display_text = "General Purpose Medium",  cpu_number = 2,  cpu_speed = 2500, memory = 2048,  network_rate = 750,  offer_ha = true,  disk_type = "fixed", root_disk_size = 20, storage_type = "shared" }
    "gen.large.fixed"   = { display_text = "General Purpose Large",   cpu_number = 4,  cpu_speed = 2500, memory = 4096,  network_rate = 1024, offer_ha = true,  disk_type = "fixed", root_disk_size = 30, storage_type = "shared" }
    "gen.xlarge.fixed"  = { display_text = "General Purpose xLarge",  cpu_number = 8,  cpu_speed = 2500, memory = 8192,  network_rate = 1024, offer_ha = true,  disk_type = "fixed", root_disk_size = 50, storage_type = "shared" }
    "gen.1xlarge.fixed" = { display_text = "General Purpose 1xLarge", cpu_number = 12, cpu_speed = 2500, memory = 12288, network_rate = 1024, offer_ha = true,  disk_type = "fixed", root_disk_size = 60, storage_type = "shared" }
    "gen.2xlarge.fixed" = { display_text = "General Purpose 2xLarge", cpu_number = 16, cpu_speed = 2500, memory = 16384, network_rate = 1024, offer_ha = true,  disk_type = "fixed", root_disk_size = 75, storage_type = "shared" }
    # ── mem family – custom shared disk ────────────────────────────────────
    "mem.tiny"     = { display_text = "Memory Optimized Tiny with Custom Disk",       cpu_number = 1,  cpu_speed = 1000, memory = 1024,  network_rate = 750,  offer_ha = true,  disk_type = "custom_shared" }
    "mem.small"    = { display_text = "Memory Optimized Small with Custom Disk",      cpu_number = 1,  cpu_speed = 2500, memory = 2048,  network_rate = 750,  offer_ha = true,  disk_type = "custom_shared" }
    "mem.medium"   = { display_text = "Memory Optimized Medium with Custom Disk",     cpu_number = 2,  cpu_speed = 2500, memory = 4096,  network_rate = 750,  offer_ha = true,  disk_type = "custom_shared" }
    "mem.large"    = { display_text = "Memory Optimized Large with Custom Disk",      cpu_number = 4,  cpu_speed = 2500, memory = 8192,  network_rate = 1024, offer_ha = true,  disk_type = "custom_shared" }
    "mem.xlarge"   = { display_text = "Memory Optimized xLarge with Custom Disk",     cpu_number = 8,  cpu_speed = 2500, memory = 16384, network_rate = 1024, offer_ha = true,  disk_type = "custom_shared" }
    "mem.1xlarge"  = { display_text = "Memory Optimized 1.5xLarge with Custom Disk",  cpu_number = 12, cpu_speed = 2500, memory = 24576, network_rate = 1024, offer_ha = true,  disk_type = "custom_shared" }
    "mem.2xlarge"  = { display_text = "Memory Optimized 2xLarge with Custom Disk",    cpu_number = 16, cpu_speed = 2500, memory = 32768, network_rate = 1024, offer_ha = true,  disk_type = "custom_shared" }
    # ── mem family – fixed disk ────────────────────────────────────────────
    "mem.tiny.fixed"    = { display_text = "Memory Optimized Tiny",    cpu_number = 1,  cpu_speed = 1000, memory = 1024,  network_rate = 500,  offer_ha = false, disk_type = "fixed", root_disk_size = 5,  storage_type = "shared" }
    "mem.small.fixed"   = { display_text = "Memory Optimized Small",   cpu_number = 1,  cpu_speed = 2500, memory = 2048,  network_rate = 750,  offer_ha = true,  disk_type = "fixed", root_disk_size = 10, storage_type = "shared" }
    "mem.medium.fixed"  = { display_text = "Memory Optimized Medium",  cpu_number = 2,  cpu_speed = 2500, memory = 4096,  network_rate = 750,  offer_ha = true,  disk_type = "fixed", root_disk_size = 20, storage_type = "shared" }
    "mem.large.fixed"   = { display_text = "Memory Optimized Large",   cpu_number = 4,  cpu_speed = 2500, memory = 8192,  network_rate = 1024, offer_ha = true,  disk_type = "fixed", root_disk_size = 30, storage_type = "shared" }
    "mem.xlarge.fixed"  = { display_text = "Memory Optimized xLarge",  cpu_number = 8,  cpu_speed = 2500, memory = 16384, network_rate = 1024, offer_ha = true,  disk_type = "fixed", root_disk_size = 50, storage_type = "shared" }
    "mem.1xlarge.fixed" = { display_text = "Memory Optimized 1xLarge", cpu_number = 12, cpu_speed = 2500, memory = 24576, network_rate = 1024, offer_ha = true,  disk_type = "fixed", root_disk_size = 60, storage_type = "shared" }
    "mem.2xlarge.fixed" = { display_text = "Memory Optimized 2xLarge", cpu_number = 16, cpu_speed = 2500, memory = 32768, network_rate = 1024, offer_ha = true,  disk_type = "fixed", root_disk_size = 75, storage_type = "shared" }
    # ── ssd family – custom local disk (ha = false, local storage) ─────────
    "ssd.tiny"     = { display_text = "Storage Optimized Tiny with Custom Disk",       cpu_number = 1,  cpu_speed = 1000, memory = 512,   network_rate = 500,  offer_ha = false, disk_type = "custom_local" }
    "ssd.small"    = { display_text = "Storage Optimized Small with Custom Disk",      cpu_number = 1,  cpu_speed = 2500, memory = 1024,  network_rate = 750,  offer_ha = false, disk_type = "custom_local" }
    "ssd.medium"   = { display_text = "Storage Optimized Medium with Custom Disk",     cpu_number = 2,  cpu_speed = 2500, memory = 2048,  network_rate = 750,  offer_ha = false, disk_type = "custom_local" }
    "ssd.large"    = { display_text = "Storage Optimized Large with Custom Disk",      cpu_number = 4,  cpu_speed = 2500, memory = 4096,  network_rate = 1024, offer_ha = false, disk_type = "custom_local" }
    "ssd.xlarge"   = { display_text = "Storage Optimized xLarge with Custom Disk",     cpu_number = 8,  cpu_speed = 2500, memory = 8192,  network_rate = 1024, offer_ha = false, disk_type = "custom_local" }
    "ssd.1xlarge"  = { display_text = "Storage Optimized 1.5xLarge with Custom Disk",  cpu_number = 12, cpu_speed = 2500, memory = 12288, network_rate = 1024, offer_ha = false, disk_type = "custom_local" }
    "ssd.2xlarge"  = { display_text = "Storage Optimized 2xLarge with Custom Disk",    cpu_number = 16, cpu_speed = 2500, memory = 16384, network_rate = 1024, offer_ha = false, disk_type = "custom_local" }
    # ── fully customized ───────────────────────────────────────────────────
    "custom.shared" = { display_text = "Custom Compute with Shared Custom Disk", is_customized = true, cpu_speed = 2500, min_cpu = 1, max_cpu = 16, min_memory = 1024, max_memory = 32768, network_rate = 1024, offer_ha = true,  disk_type = "custom_shared" }
    "custom.local"  = { display_text = "Custom Compute with Local Custom Disk",  is_customized = true, cpu_speed = 2500, min_cpu = 1, max_cpu = 16, min_memory = 1024, max_memory = 32768, network_rate = 1024, offer_ha = false, disk_type = "custom_local" }
  }

  # ── Network Offerings (map: name → config) ────────────────────────────────
  # lb_provider: "VirtualRouter" | "InternalLbVm" | "VpcVirtualRouter" | null
  # lb_type:     "publicLb" | "internalLb" | null
  network_offerings = {
    "shared.core-redundant" = {
      display_text     = "Shared Network with Redundant Virtual Router"
      guest_ip_type    = "Shared"
      for_vpc          = false
      is_persistent    = false
      specify_vlan     = false
      redundant_router = true
      lb_type          = "publicLb"
      lb_provider      = "VirtualRouter"
      services         = ["Vpn", "Dhcp", "Dns", "Firewall", "Lb", "UserData", "SourceNat", "StaticNat", "PortForwarding"]
    }
    "shared.core-redundant-vlan" = {
      display_text     = "Shared Network with Redundant Virtual Router and VLAN specified"
      guest_ip_type    = "Shared"
      for_vpc          = false
      is_persistent    = false
      specify_vlan     = true
      redundant_router = true
      lb_type          = "publicLb"
      lb_provider      = "VirtualRouter"
      services         = ["Vpn", "Dhcp", "Dns", "Firewall", "Lb", "UserData", "SourceNat", "StaticNat", "PortForwarding"]
    }
    "isolated.core" = {
      display_text     = "Isolated Network with Virtual Router"
      guest_ip_type    = "Isolated"
      for_vpc          = false
      is_persistent    = true
      specify_vlan     = false
      redundant_router = false
      lb_type          = "publicLb"
      lb_provider      = "VirtualRouter"
      services         = ["Vpn", "Dhcp", "Dns", "Firewall", "Lb", "UserData", "SourceNat", "StaticNat", "PortForwarding"]
    }
    "isolated.core-redundant" = {
      display_text     = "Isolated Network with Redundant Virtual Router"
      guest_ip_type    = "Isolated"
      for_vpc          = false
      is_persistent    = true
      specify_vlan     = false
      redundant_router = true
      lb_type          = "publicLb"
      lb_provider      = "VirtualRouter"
      services         = ["Vpn", "Dhcp", "Dns", "Firewall", "Lb", "UserData", "SourceNat", "StaticNat", "PortForwarding"]
    }
    "vpc.core-internal-lb" = {
      display_text     = "VPC Network with VpcVirtualRouter and Internal LB VM"
      guest_ip_type    = "Isolated"
      for_vpc          = true
      is_persistent    = true
      specify_vlan     = false
      redundant_router = false
      lb_type          = "internalLb"
      lb_provider      = "InternalLbVm"
      services         = ["Vpn", "Dhcp", "Dns", "Lb", "UserData", "SourceNat", "StaticNat", "PortForwarding", "NetworkACL"]
    }
    "vpc.core-public-lb" = {
      display_text     = "VPC Network with VpcVirtualRouter and Public LB"
      guest_ip_type    = "Isolated"
      for_vpc          = true
      is_persistent    = true
      specify_vlan     = false
      redundant_router = false
      lb_type          = "publicLb"
      lb_provider      = "VpcVirtualRouter"
      services         = ["Vpn", "Dhcp", "Dns", "Lb", "UserData", "SourceNat", "StaticNat", "PortForwarding", "NetworkACL"]
    }
  }

  # ── VPC Offerings (map: name → config) ───────────────────────────────────
  vpc_offerings = {
    "natted.core" = {
      display_text     = "NATTED Single Virtual Router VPC with VpcVirtualRouter, ConfigDrive, InternalLbVm"
      redundant_router = false
      services         = ["Vpn", "Dhcp", "Dns", "Lb", "Gateway", "UserData", "SourceNat", "StaticNat", "PortForwarding", "NetworkACL"]
    }
    "natted.redundant-core" = {
      display_text     = "NATTED Redundant Virtual Router VPC with VpcVirtualRouter, ConfigDrive, InternalLbVm"
      redundant_router = true
      services         = ["Vpn", "Dhcp", "Dns", "Lb", "Gateway", "UserData", "SourceNat", "StaticNat", "PortForwarding", "NetworkACL"]
    }
  }

  # ── Templates / Images (map: key → config) ────────────────────────────────
  # All templates use lifecycle { prevent_destroy = true } — never auto-deleted.
  # To decommission, first stop VMs using it, then delete manually.
  templates = {
    "ubuntu-24.04" = {
      name         = "Ubuntu 24.04 - Noble"
      display_text = "Ubuntu 24.04 LTS Cloud Image"
      url          = "https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img"
      format       = "QCOW2"
      hypervisor   = "KVM"
      os_type      = "Ubuntu 24.04"
      is_featured  = true
      details = {
        keyboard       = "us"
        rootdisksize   = "10"
        "guest.cpu.mode" = "host-model"
      }
    }
    "debian-12" = {
      name         = "Debian 12 - Bookworm"
      display_text = "Debian 12 Bookworm"
      url          = "https://cdimage.debian.org/images/cloud/bookworm/latest/debian-12-nocloud-amd64.qcow2"
      format       = "QCOW2"
      hypervisor   = "KVM"
      os_type      = "Debian GNU/Linux 12 (64-bit)"
      is_featured  = true
      details = {
        keyboard       = "us"
        rootdisksize   = "10"
        "guest.cpu.mode" = "host-model"
      }
    }
    "talos-v1.12.6" = {
      name         = "Talos v1.12.6 - CloudStack"
      display_text = "Talos Linux v1.12.6 for CloudStack (btrfs, nfs, qemu-guest-agent)"
      # Schematic: 23ff67af89fd08e5703f919f9b58c5a4a6de2540b1f8ca83379e19321560b1bf
      # Extensions: btrfs, nfs-utils, nfsd, nfsrahead, qemu-guest-agent
      # NOTE: Try dropping .gz suffix if CloudStack rejects the compressed image
      url          = "https://factory.talos.dev/image/23ff67af89fd08e5703f919f9b58c5a4a6de2540b1f8ca83379e19321560b1bf/v1.12.6/cloudstack-amd64.raw.gz"
      format       = "RAW"
      hypervisor   = "KVM"
      os_type      = "Other (64-bit)"
      is_featured  = false
      details      = {}
    }
  }

  # ── ISOs (map: key → config; lifecycle prevent_destroy = true) ───────────
  # Optional: set enable_isos = false to skip all ISO registration.
  enable_isos = true
  isos = {
    "windows-server-2025" = {
      name         = "windows-server-2025"
      display_text = "Windows Server 2025 ISO"
      url          = "https://software-static.download.prss.microsoft.com/dbazure/888969d5-f34g-4e03-ac9d-1f9786c66749/26100.1742.240906-0331.ge_release_svc_refresh_SERVER_EVAL_x64FRE_en-us.iso"
      os_type      = "Windows Server 2025"
      bootable     = true
      is_featured  = true
    }
    "virtio-win" = {
      name         = "virtio-win"
      display_text = "VirtIO drivers for Windows VMs"
      url          = "https://fedorapeople.org/groups/virt/virtio-win/direct-downloads/stable-virtio/virtio-win.iso"
      os_type      = "Other (64-bit)"
      bootable     = false
      is_featured  = false
    }
  }

  # ── CKS Kubernetes Supported Versions ────────────────────────────────────
  # Intentionally omitted — CKS and Cluster API are not used.
  # Kubernetes clusters are deployed via Talos Linux on CloudStack VMs.

  # ── Import IDs (existing resources) ──────────────────────────────────────
  # Gathered via: cmk -p admin list <resource> --output json | python3 -c "..."

  existing_pod_id     = "437e4b1b-f7a6-4d38-9a67-52debb897f9e"
  existing_cluster_id = "fb716f9f-442d-486b-9f39-40e9bd48c3d3"
  existing_domain_id  = "0988c278-9ced-4232-9d3f-ab6399509ac3"
  existing_account_id = "5059e8e4-2b22-4cff-9f20-8e7714f8aae2"

  existing_physical_network_ids = {
    "cloudbr0" = "38d9034f-b8e8-45bc-b097-aa18a1820e87"
    "cloudbr1" = "bf0380db-b75a-4edf-bd33-8b94334998c1"
  }

  # Key: "<physical_network_name>/<traffic_type>"
  existing_traffic_type_ids = {
    "cloudbr0/Management" = "88a30b08-8ceb-42e5-897b-c89e136bc5af"
    "cloudbr1/Guest"      = "2ccffcef-69e5-4174-acf3-b7cbf2a6ebae"
    "cloudbr1/Public"     = "c5b22dd7-1318-4449-8994-066856dc7a85"
  }

  # Key: "<physical_network_name>" (one per net that has a public_ip_range)
  existing_vlan_ip_range_ids = {
    "cloudbr1" = "80e13299-2fbe-4aa7-85cf-fc54551e7255"
  }

  existing_storage_pool_ids = {
    "primary-nfs-zone-homecloud"  = "ec9a9f09-5cf7-3b6a-b7d4-1e9259309397"
    "primary-nfs2-zone-homecloud" = "7f0d6345-a7e9-37a7-86a8-632a2be79992"
  }

  existing_secondary_storage_ids = {
    "secondary-nfs-zone-homecloud"  = "7dc4b70d-df09-4472-87c8-d8139bb4885e"
    "secondary-nfs2-zone-homecloud" = "8a46ded1-679c-4318-b6f0-5593ae00623b"
  }

  # Fixed disk offerings only (customized ones are null_resource, not imported)
  existing_disk_offering_ids = {
    "shared.small"  = "bd4a1d3c-fdd2-4cd4-9f26-1cb79f018d16"
    "shared.medium" = "5a910532-2ee4-4d47-aa20-9f09ba6ee42d"
    "shared.large"  = "2cb61e7f-f92d-4749-8b7e-f872f168911f"
    "shared.xlarge" = "20a1d2d2-6bf6-4ae3-abfc-bbc433b7f6e3"
    "local.small"   = "35d7aa10-e9b1-48cb-9c98-a1fce7dd763e"
    "local.medium"  = "d4246c80-f6c1-45cf-bfdd-8973cdd9c0f4"
    "local.large"   = "778ef406-84b5-4509-bb87-3b7cae524feb"
    "local.xlarge"  = "98480c7f-66f7-4549-a26e-205ab95000ce"
  }

  # UUIDs for customized disk offerings (used by unconstrained compute offerings)
  # shared.custom already exists; local.custom will be created on first apply
  custom_disk_offering_ids = {
    "shared.custom" = "8b04b5c4-bec1-479d-aa03-37a0f302640b"
  }

  existing_compute_offering_ids = {
    # fixed disk (cloudstack_service_offering_fixed)
    "gen.small.fixed"   = "87e8ed4a-9e03-416e-b749-a6faa891ed5a"
    "gen.medium.fixed"  = "83e0a325-1d47-4f4f-a1f5-a5a61a02a77f"
    "gen.large.fixed"   = "d8724bd9-a714-47ac-9f32-128dbffadaac"
    "gen.xlarge.fixed"  = "be4a3110-683d-4c3b-a54c-65dd923457e4"
    "gen.1xlarge.fixed" = "fc1ecc51-08ff-49c7-9be1-94e29f489c04"
    "gen.2xlarge.fixed" = "4433ea6d-0274-48a3-b9e3-0e9e15086baa"
    "mem.tiny.fixed"    = "0dfed425-adb8-495e-9b58-99f04b45283b"
    "mem.small.fixed"   = "dad3daa7-17e5-4b48-ba1f-ab250870f9d0"
    "mem.medium.fixed"  = "6226b1d5-e1d5-4b14-a7c3-7638a26ec869"
    "mem.large.fixed"   = "5b31865c-8c0f-498f-8073-aebaf3493cd7"
    "mem.xlarge.fixed"  = "3a22b349-d862-4972-a6fb-d36c62292f0f"
    "mem.1xlarge.fixed" = "5fb8a6e1-4e3b-473c-9fff-ea023dd13df5"
    "mem.2xlarge.fixed" = "122ca5c9-a127-4fae-8d7e-fa58d75d7046"
    # unconstrained (custom shared disk — cloudstack_service_offering_unconstrained)
    "gen.tiny"    = "332066e4-41a8-409c-bd04-9725ab8873c0"
    "gen.small"   = "690e3360-841b-4de3-9c72-ab2dc4e5353e"
    "gen.medium"  = "eb2cb595-260a-4f73-a571-1b7755d1e221"
    "gen.large"   = "29049a6d-1422-4147-9d85-399d3646e72b"
    "gen.xlarge"  = "0faf9821-ba32-4de0-bfa7-e6bc06e205c0"
    "gen.1xlarge" = "7d42bfc1-c2cf-4c15-9344-1e63d5ad8c89"
    "gen.2xlarge" = "44139aac-ce88-4936-85b6-8bb465e35ddb"
    "mem.tiny"    = "ec1ec9c8-8fde-4c57-9a60-8b1066fee5ec"
    "mem.small"   = "f018ce0d-4800-4759-9383-68706fcd19bc"
    "mem.medium"  = "bcb6abb5-1e50-4b34-aecb-5f68b7776933"
    "mem.large"   = "b39c3ef5-cb50-48f6-b417-e4e1cc600ea8"
    "mem.xlarge"  = "887609b3-ba2d-48d5-9e3a-36c83e22db7b"
    "mem.1xlarge" = "c8892343-7cd3-44d4-a4ad-324c5c50f90a"
    "mem.2xlarge" = "078f10f9-86b3-4898-a43a-ca96a5e099b9"
    # unconstrained (custom local disk — ssd family)
    "ssd.tiny"    = "85f024ce-c917-43a4-84d1-25be65570497"
    "ssd.small"   = "d1250bbe-2d62-4b48-8691-62354c895f95"
    "ssd.medium"  = "de2a32c1-8a86-4581-a213-9eb553f938da"
    "ssd.large"   = "c46fbcd0-58ab-453f-bac4-33c91cdcfea2"
    "ssd.xlarge"  = "1b71e573-2fa3-43d3-bdd6-d52f29ccd95a"
    "ssd.1xlarge" = "5fa01567-1404-440c-90d5-13b7b67a48b7"
    "ssd.2xlarge" = "58d97141-634d-40da-99b5-6ccf04730b0c"
    # constrained (fully custom CPU+RAM — cloudstack_service_offering_constrained)
    "custom.shared" = "27edafb4-2f03-43df-954a-1cf60aa389b4"
    "custom.local"  = "749d1b1a-4a52-45cc-be92-c3bba2a2ffff"
  }

  existing_network_offering_ids = {
    "shared.core-redundant"      = "036562dc-0bd8-41e2-b567-d8efcd219498"
    "shared.core-redundant-vlan" = "c1f62807-0037-4696-9b3d-5d8c8c267251"
    "isolated.core"              = "f118c71b-a680-44c1-a172-93d3615990fe"
    "isolated.core-redundant"    = "200f34db-6172-49f9-9fba-077a252d71e8"
    "vpc.core-internal-lb"       = "7e2334a3-4adc-4801-80ad-272503a18291"
    "vpc.core-public-lb"         = "d90bb14c-258a-4ca2-b980-b99555d15fcf"
  }

  # VPC offerings: managed via null_resource (no native TF import), but UUIDs
  # are passed so the idempotency check in the shell script can skip creation.
  existing_vpc_offering_ids = {
    "natted.core"          = "6777abba-4f73-4157-b193-976d67caabad"
    "natted.redundant-core" = "aed5447c-9137-499a-9324-b2325b191bad"
  }

  # Templates that already exist in CloudStack (talos-v1.12.6 will be created)
  existing_template_ids = {
    "ubuntu-24.04" = "4fc92545-1449-4abc-a117-81eb12f8c4b3"
    "debian-12"    = "92836512-9b86-4c1f-a270-b79c288104ec"
  }
}
