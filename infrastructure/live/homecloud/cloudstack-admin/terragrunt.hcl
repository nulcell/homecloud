# cloudstack-admin unit — admin-scope CloudStack resources (cloudstack.admin provider ONLY).
# Zone infra, domain/account, offerings, templates, ISOs. Not VPC/networks/VMs.

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
  # zone_dns1          = include.account.locals.zone_dns1
  # zone_internal_dns1 = include.account.locals.zone_internal_dns1
  # zone_network_type  = include.account.locals.zone_network_type

  # ── Global Settings (map: config_name → value) ───────────────────────────
  global_settings = {
    # Access
    "metadata.allow.expose.domain" = "true"
    # Compute – VM
    "cluster.cpu.allocated.capacity.disablethreshold"                          = "1"
    "cluster.cpu.allocated.capacity.notificationthreshold"                     = "1"
    "enable.additional.vm.configuration"                                       = "true"
    "enable.dynamic.scale.vm"                                                  = "true"
    "instance.lease.enabled"                                                   = "true"
    "system.vm.default.hypervisor"                                             = "KVM"
    "vm.allocation.algorithm"                                                  = "userdispersing"
    "vm.deployment.planner"                                                    = "UserDispersingPlanner"
    "vm.destroy.forcestop"                                                     = "true"
    "vm.display.ovf.properties"                                                = "true"
    "vm.password.length"                                                       = "12"
    "vm.userdata.max.length"                                                   = "1048576"
    "cpu.overprovisioning.factor"                                              = "1.25"
    "vm.min.cpu.speed.equals.cpu.speed.divided.by.cpu.overprovisioning.factor" = "false"
    "vm.min.memory.equals.memory.divided.by.mem.overprovisioning.factor"       = "false"
    "vm.serviceoffering.cpu.cores.max"                                         = "16"
    "vm.serviceoffering.ram.size.max"                                          = "32768"
    "user.vm.readonly.details"                                                 = ""
    "user.vm.denied.details"                                                   = "cpuOvercommitRatio,memoryOvercommitRatio"
    # Storage
    "destroy.root.volume.on.vm.destruction" = "true"
    "snapshot.delta.max"                    = "32"
    "storage.overprovisioning.factor"       = "2"
    # Network
    "network.throttling.rate"         = "500"
    "vpc.max.networks"                = "4"
    "vpc.tier.name.prepend"           = "true"
    "vpc.tier.name.prepend.delimiter" = "_"
    "cloud.dns.name"                  = "homecloud.internal"
    "guest.domain.suffix"             = "homecloud.internal"
    # Hypervisor – KVM
    "enable.kvm.host.auto.enable.disable" = "true"
    "kvm.incremental.snapshot"            = "true"
    # API
    "enable.ec2.api" = "true"
    "enable.s3.api"  = "true"
    # Console
    "consoleproxy.sslEnabled" = "true"
    # Miscellaneous
    "endpoint.url"                    = "http://10.10.17.5:8080/client/api"
    "store.download.follow.redirects" = "true"
    "mem.overprovisioning.factor"     = "1.25"
  }

  # zone = {
  #   dns1                                = "10.10.31.254"
  #   dns2                                = "8.8.8.8"
  #   internal_dns1                       = "10.10.31.254"
  #   guest_cidr                          = "10.0.0.0/24"
  #   network_domain                      = "homecloud.internal"
  #   local_storage_enabled               = true
  #   local_storage_enabled_for_system_vm = false
  # }

  # # Two physical networks: cloudbr0 (Management) and cloudbr1 (Public + Guest)
  # physical_networks = {
  #   "cloudbr0" = {
  #     isolation_method = "VLAN"
  #     traffic_types    = ["Management"]
  #     vlan_range       = null
  #     public_ip_range  = null
  #     service_providers = {
  #       "VirtualRouter"        = { service_list = ["Vpn", "Dhcp", "Dns", "Firewall", "Lb", "SourceNat", "StaticNat", "PortForwarding", "UserData"] }
  #       "VpcVirtualRouter"     = { service_list = ["Vpn", "Dhcp", "Dns", "Lb", "SourceNat", "StaticNat", "PortForwarding", "UserData","NetworkACL"] }
  #       # "SecurityGroupProvider" = { service_list = ["SecurityGroup"] }
  #       "InternalLbVm"         = { service_list = ["Lb"] }
  #       "ConfigDrive"          = { service_list = ["Dhcp", "Dns", "UserData"] }
  #     }
  #   }
  #   "cloudbr1" = {
  #     isolation_method = "VLAN"
  #     traffic_types    = ["Public", "Guest"]
  #     vlan_range       = "500-700"
  #     service_providers = {
  #       "VirtualRouter"        = { service_list = ["Vpn", "Dhcp", "Dns", "Firewall", "Lb", "SourceNat", "StaticNat", "PortForwarding", "UserData"] }
  #       "VpcVirtualRouter"     = { service_list = ["Vpn", "Dhcp", "Dns", "Lb", "SourceNat", "StaticNat", "PortForwarding", "UserData","NetworkACL"] }
  #       # "SecurityGroupProvider" = { service_list = ["SecurityGroup"] }
  #       "InternalLbVm"         = { service_list = ["Lb"] }
  #       "ConfigDrive"          = { service_list = ["Dhcp", "Dns", "UserData"] }
  #     }
  #     public_ip_range = {
  #       gateway  = "10.10.31.254"
  #       netmask  = "255.255.240.0"
  #       start_ip = "10.10.20.1"
  #       end_ip   = "10.10.20.254"
  #       vlan     = "vlan://untagged"
  #     }
  #   }
  # }

  # pod = {
  #   name     = "pod-homecloud"
  #   gateway  = "10.10.31.254"
  #   netmask  = "255.255.240.0"
  #   start_ip = "10.10.21.1"
  #   end_ip   = "10.10.21.254"
  # }

  # cluster = {
  #   name       = "cluster-homecloud"
  #   hypervisor = "KVM"
  # }

  # # map: ip_address → { username }
  # hosts = {
  #   "10.10.17.5"  = { username = "root" }
  #   # "10.10.17.10" = { username = "root" }
  # }

  # # map: name → { server, path }  (zone-wide NFS primary storage)
  # primary_storage_pools = {
  #   "primary-nfs-zone-homecloud" = { server = "10.10.17.5", path = "/export/primary" }
  #   # "primary-nfs2-zone-homecloud"  = { server = "10.10.17.10", path = "/export/primary" }
  # }

  # # map: name → { server, path }  (NFS image stores — null_resource, no native TF resource)
  # secondary_storage = {
  #   "secondary-nfs-zone-homecloud" = { server = "10.10.17.5", path = "/export/secondary" }
  #   # "secondary-nfs2-zone-homecloud"  = { server = "10.10.17.10", path = "/export/secondary" }
  # }

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
    "local.custom"  = { display_text = "Local Storage Custom Size Disk", storage_type = "local", customized = true }
    "shared.small"  = { display_text = "Shared Storage Small Disk", storage_type = "shared", disk_size = 30 }
    "shared.medium" = { display_text = "Shared Storage Medium Disk", storage_type = "shared", disk_size = 50 }
    "shared.large"  = { display_text = "Shared Storage Large Disk", storage_type = "shared", disk_size = 100 }
    "shared.xlarge" = { display_text = "Shared Storage XLarge Disk", storage_type = "shared", disk_size = 200 }
    "local.small"   = { display_text = "Local Storage Small Disk", storage_type = "local", disk_size = 30 }
    "local.medium"  = { display_text = "Local Storage Medium Disk", storage_type = "local", disk_size = 50 }
    "local.large"   = { display_text = "Local Storage Large Disk", storage_type = "local", disk_size = 100 }
    "local.xlarge"  = { display_text = "Local Storage XLarge Disk", storage_type = "local", disk_size = 200 }
  }

  # ── Compute Offerings ─────────────────────────────────────────────────────
  # disk_type:
  #   "custom_shared" → disk_offering = shared.custom  (dynamic scaling enabled)
  #   "custom_local"  → disk_offering = local.custom   (ssd family, ha = false)
  #   "fixed"         → storage_type + root_disk_size baked in (dynamic scaling disabled)
  #   "customized"    → fully custom CPU+RAM+disk (custom.* offerings)
  compute_offerings = {
    # ── gen family – custom shared disk ────────────────────────────────────
    "gen.tiny"    = { display_text = "General Purpose Tiny with Custom Disk", cpu_number = 1, cpu_speed = 1000, memory = 512, network_rate = 500, offer_ha = true, disk_type = "custom_shared" }
    "gen.small"   = { display_text = "General Purpose Small with Custom Disk", cpu_number = 1, cpu_speed = 2500, memory = 1024, network_rate = 750, offer_ha = true, disk_type = "custom_shared" }
    "gen.medium"  = { display_text = "General Purpose Medium with Custom Disk", cpu_number = 2, cpu_speed = 2500, memory = 2048, network_rate = 750, offer_ha = true, disk_type = "custom_shared" }
    "gen.large"   = { display_text = "General Purpose Large with Custom Disk", cpu_number = 4, cpu_speed = 2500, memory = 4096, network_rate = 1024, offer_ha = true, disk_type = "custom_shared" }
    "gen.xlarge"  = { display_text = "General Purpose xLarge with Custom Disk", cpu_number = 8, cpu_speed = 2500, memory = 8192, network_rate = 1024, offer_ha = true, disk_type = "custom_shared" }
    "gen.1xlarge" = { display_text = "General Purpose 1.5xLarge with Custom Disk", cpu_number = 12, cpu_speed = 2500, memory = 12288, network_rate = 1024, offer_ha = true, disk_type = "custom_shared" }
    "gen.2xlarge" = { display_text = "General Purpose 2xLarge with Custom Disk", cpu_number = 16, cpu_speed = 2500, memory = 16384, network_rate = 1024, offer_ha = true, disk_type = "custom_shared" }
    # ── gen family – fixed disk ────────────────────────────────────────────
    "gen.small.fixed"   = { display_text = "General Purpose Small", cpu_number = 1, cpu_speed = 2500, memory = 1024, network_rate = 750, offer_ha = true, disk_type = "fixed", root_disk_size = 10, storage_type = "shared" }
    "gen.medium.fixed"  = { display_text = "General Purpose Medium", cpu_number = 2, cpu_speed = 2500, memory = 2048, network_rate = 750, offer_ha = true, disk_type = "fixed", root_disk_size = 20, storage_type = "shared" }
    "gen.large.fixed"   = { display_text = "General Purpose Large", cpu_number = 4, cpu_speed = 2500, memory = 4096, network_rate = 1024, offer_ha = true, disk_type = "fixed", root_disk_size = 30, storage_type = "shared" }
    "gen.xlarge.fixed"  = { display_text = "General Purpose xLarge", cpu_number = 8, cpu_speed = 2500, memory = 8192, network_rate = 1024, offer_ha = true, disk_type = "fixed", root_disk_size = 50, storage_type = "shared" }
    "gen.1xlarge.fixed" = { display_text = "General Purpose 1xLarge", cpu_number = 12, cpu_speed = 2500, memory = 12288, network_rate = 1024, offer_ha = true, disk_type = "fixed", root_disk_size = 60, storage_type = "shared" }
    "gen.2xlarge.fixed" = { display_text = "General Purpose 2xLarge", cpu_number = 16, cpu_speed = 2500, memory = 16384, network_rate = 1024, offer_ha = true, disk_type = "fixed", root_disk_size = 75, storage_type = "shared" }
    # ── mem family – custom shared disk ────────────────────────────────────
    "mem.tiny"    = { display_text = "Memory Optimized Tiny with Custom Disk", cpu_number = 1, cpu_speed = 1000, memory = 1024, network_rate = 750, offer_ha = true, disk_type = "custom_shared" }
    "mem.small"   = { display_text = "Memory Optimized Small with Custom Disk", cpu_number = 1, cpu_speed = 2500, memory = 2048, network_rate = 750, offer_ha = true, disk_type = "custom_shared" }
    "mem.medium"  = { display_text = "Memory Optimized Medium with Custom Disk", cpu_number = 2, cpu_speed = 2500, memory = 4096, network_rate = 750, offer_ha = true, disk_type = "custom_shared" }
    "mem.large"   = { display_text = "Memory Optimized Large with Custom Disk", cpu_number = 4, cpu_speed = 2500, memory = 8192, network_rate = 1024, offer_ha = true, disk_type = "custom_shared" }
    "mem.xlarge"  = { display_text = "Memory Optimized xLarge with Custom Disk", cpu_number = 8, cpu_speed = 2500, memory = 16384, network_rate = 1024, offer_ha = true, disk_type = "custom_shared" }
    "mem.1xlarge" = { display_text = "Memory Optimized 1.5xLarge with Custom Disk", cpu_number = 12, cpu_speed = 2500, memory = 24576, network_rate = 1024, offer_ha = true, disk_type = "custom_shared" }
    "mem.2xlarge" = { display_text = "Memory Optimized 2xLarge with Custom Disk", cpu_number = 16, cpu_speed = 2500, memory = 32768, network_rate = 1024, offer_ha = true, disk_type = "custom_shared" }
    # ── mem family – fixed disk ────────────────────────────────────────────
    "mem.tiny.fixed"    = { display_text = "Memory Optimized Tiny", cpu_number = 1, cpu_speed = 1000, memory = 1024, network_rate = 500, offer_ha = false, disk_type = "fixed", root_disk_size = 5, storage_type = "shared" }
    "mem.small.fixed"   = { display_text = "Memory Optimized Small", cpu_number = 1, cpu_speed = 2500, memory = 2048, network_rate = 750, offer_ha = true, disk_type = "fixed", root_disk_size = 10, storage_type = "shared" }
    "mem.medium.fixed"  = { display_text = "Memory Optimized Medium", cpu_number = 2, cpu_speed = 2500, memory = 4096, network_rate = 750, offer_ha = true, disk_type = "fixed", root_disk_size = 20, storage_type = "shared" }
    "mem.large.fixed"   = { display_text = "Memory Optimized Large", cpu_number = 4, cpu_speed = 2500, memory = 8192, network_rate = 1024, offer_ha = true, disk_type = "fixed", root_disk_size = 30, storage_type = "shared" }
    "mem.xlarge.fixed"  = { display_text = "Memory Optimized xLarge", cpu_number = 8, cpu_speed = 2500, memory = 16384, network_rate = 1024, offer_ha = true, disk_type = "fixed", root_disk_size = 50, storage_type = "shared" }
    "mem.1xlarge.fixed" = { display_text = "Memory Optimized 1xLarge", cpu_number = 12, cpu_speed = 2500, memory = 24576, network_rate = 1024, offer_ha = true, disk_type = "fixed", root_disk_size = 60, storage_type = "shared" }
    "mem.2xlarge.fixed" = { display_text = "Memory Optimized 2xLarge", cpu_number = 16, cpu_speed = 2500, memory = 32768, network_rate = 1024, offer_ha = true, disk_type = "fixed", root_disk_size = 75, storage_type = "shared" }
    # ── ssd family – custom local disk (ha = false, local storage) ─────────
    "ssd.tiny"    = { display_text = "Storage Optimized Tiny with Custom Disk", cpu_number = 1, cpu_speed = 1000, memory = 512, network_rate = 500, offer_ha = false, disk_type = "custom_local" }
    "ssd.small"   = { display_text = "Storage Optimized Small with Custom Disk", cpu_number = 1, cpu_speed = 2500, memory = 1024, network_rate = 750, offer_ha = false, disk_type = "custom_local" }
    "ssd.medium"  = { display_text = "Storage Optimized Medium with Custom Disk", cpu_number = 2, cpu_speed = 2500, memory = 2048, network_rate = 750, offer_ha = false, disk_type = "custom_local" }
    "ssd.large"   = { display_text = "Storage Optimized Large with Custom Disk", cpu_number = 4, cpu_speed = 2500, memory = 4096, network_rate = 1024, offer_ha = false, disk_type = "custom_local" }
    "ssd.xlarge"  = { display_text = "Storage Optimized xLarge with Custom Disk", cpu_number = 8, cpu_speed = 2500, memory = 8192, network_rate = 1024, offer_ha = false, disk_type = "custom_local" }
    "ssd.1xlarge" = { display_text = "Storage Optimized 1.5xLarge with Custom Disk", cpu_number = 12, cpu_speed = 2500, memory = 12288, network_rate = 1024, offer_ha = false, disk_type = "custom_local" }
    "ssd.2xlarge" = { display_text = "Storage Optimized 2xLarge with Custom Disk", cpu_number = 16, cpu_speed = 2500, memory = 16384, network_rate = 1024, offer_ha = false, disk_type = "custom_local" }
    # ── fully customized ───────────────────────────────────────────────────
    "custom.shared" = { display_text = "Custom Compute with Shared Custom Disk", is_customized = true, cpu_speed = 2500, min_cpu = 1, max_cpu = 16, min_memory = 1024, max_memory = 32768, network_rate = 1024, offer_ha = true, disk_type = "custom_shared" }
    "custom.local"  = { display_text = "Custom Compute with Local Custom Disk", is_customized = true, cpu_speed = 2500, min_cpu = 1, max_cpu = 16, min_memory = 1024, max_memory = 32768, network_rate = 1024, offer_ha = false, disk_type = "custom_local" }
  }

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

  # Templates use lifecycle { prevent_destroy = true } — never auto-deleted.
  templates = {
    "ubuntu-24.04" = {
      name         = "Ubuntu 24.04 - Noble"
      display_text = "Ubuntu 24.04 LTS Cloud Image"
      url          = "https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img"
      format       = "QCOW2"
      hypervisor   = "KVM"
      os_type      = "Ubuntu 24.04 LTS"
      is_featured  = true
      details = {
        keyboard         = "us"
        rootdisksize     = "10"
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
        keyboard         = "us"
        rootdisksize     = "10"
        "guest.cpu.mode" = "host-model"
      }
    }
    "talos-v1.12.6" = {
      name         = "Talos v1.12.6 - CloudStack"
      display_text = "Talos Linux v1.12.6 for CloudStack (btrfs, nfs, qemu-guest-agent)"
      # Schematic: 23ff67af89fd08e5703f919f9b58c5a4a6de2540b1f8ca83379e19321560b1bf
      # Extensions: btrfs, nfs-utils, nfsd, nfsrahead, qemu-guest-agent
      url            = "https://nulcell-talos-iu1g32s97v3qp7wg.s3.eu-central-1.amazonaws.com/v1.12.6/cloudstack-amd64.raw.gz"
      format         = "RAW"
      hypervisor     = "KVM"
      os_type        = "Other Linux (64-bit)"
      is_featured    = false
      is_extractable = true
    }
  }

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
}
