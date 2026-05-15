# cloudstack-offerings

Manages all CloudStack service offerings: disk offerings, compute (service) offerings, network offerings, and VPC offerings.

## Usage

```hcl
module "offerings" {
  source = "../../modules/cloudstack-offerings"

  disk_offerings = {
    "shared.custom" = {
      display_text = "Shared Storage Custom Size Disk"
      storage_type = "shared"
      customized   = true
    }
  }

  compute_offerings = {
    "gen.medium" = {
      display_text = "General Purpose Medium with Custom Disk"
      cpu_number   = 2
      memory       = 2048
      disk_type    = "custom_shared"
    }
  }

  network_offerings = {
    "isolated.core" = {
      display_text  = "Isolated Network with Virtual Router"
      guest_ip_type = "Isolated"
      for_vpc       = false
      is_persistent = true
      lb_type       = "publicLb"
      lb_provider   = "VirtualRouter"
      services      = ["Dhcp", "Dns", "Firewall", "Lb", "SourceNat", "StaticNat", "PortForwarding"]
    }
  }

  vpc_offerings = {
    "natted.core" = {
      display_text = "NATTED VPC with VpcVirtualRouter"
      services     = ["Vpn", "Dhcp", "Dns", "Lb", "Gateway", "SourceNat", "StaticNat", "PortForwarding", "NetworkACL"]
    }
  }

  # Existing UUIDs for import
  existing_disk_offering_ids    = { "shared.custom" = "uuid-..." }
  existing_compute_offering_ids = {}
  existing_network_offering_ids = {}
  existing_vpc_offering_ids     = {}
}
```

## Inputs

| Name | Type | Required | Description |
|------|------|----------|-------------|
| `disk_offerings` | `map(object)` | no | Disk offerings to manage. |
| `compute_offerings` | `map(object)` | no | Compute (service) offerings to manage. |
| `network_offerings` | `map(object)` | no | Network offerings to manage. |
| `vpc_offerings` | `map(object)` | no | VPC offerings to manage. |
| `existing_disk_offering_ids` | `map(string)` | no | Name → UUID for import of pre-existing disk offerings. |
| `existing_compute_offering_ids` | `map(string)` | no | Name → UUID for import of pre-existing compute offerings. |
| `existing_network_offering_ids` | `map(string)` | no | Name → UUID for import of pre-existing network offerings. |
| `existing_vpc_offering_ids` | `map(string)` | no | Name → UUID for import of pre-existing VPC offerings. |

### `compute_offerings` object fields

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `display_text` | string | required | Human-readable name. |
| `cpu_number` | number | null | vCPU count (omit for customized). |
| `cpu_speed` | number | 2500 | CPU speed in MHz. |
| `memory` | number | null | RAM in MiB (omit for customized). |
| `network_rate` | number | 1024 | Network throttle in Mbps. |
| `offer_ha` | bool | true | Enable HA for VMs using this offering. |
| `disk_type` | string | required | `"custom_shared"`, `"custom_local"`, `"fixed"`. |
| `root_disk_size` | number | null | Root disk GiB (only for `disk_type = "fixed"`). |
| `storage_type` | string | null | `"shared"`/`"local"` (only for `disk_type = "fixed"`). |
| `is_customized` | bool | false | Fully custom CPU+RAM at launch time. |
| `min_cpu` | number | null | Min vCPU (when `is_customized = true`). |
| `max_cpu` | number | null | Max vCPU (when `is_customized = true`). |
| `min_memory` | number | null | Min RAM MiB (when `is_customized = true`). |
| `max_memory` | number | null | Max RAM MiB (when `is_customized = true`). |

## Outputs

| Name | Description |
|------|-------------|
| `disk_offering_ids` | Map of disk offering name → UUID. |
| `compute_offering_ids` | Map of compute offering name → UUID. |
| `network_offering_ids` | Map of network offering name → UUID. |
| `vpc_offering_ids` | Map of VPC offering name → UUID. |

## Importing pre-existing offerings

Look up offering UUIDs with cloudmonkey:

```bash
# Disk offerings
cmk -p admin list diskofferings | jq -r '.diskoffering[] | "\(.name): \(.id)"'

# Service (compute) offerings
cmk -p admin list serviceofferings | jq -r '.serviceoffering[] | "\(.name): \(.id)"'

# Network offerings
cmk -p admin list networkofferings | jq -r '.networkoffering[] | "\(.name): \(.id)"'

# VPC offerings
cmk -p admin list vpcofferings | jq -r '.vpcoffering[] | "\(.name): \(.id)"'
```

Pass the UUIDs via the `existing_*_ids` maps. Terraform's `import {}` blocks will reconcile state on the next `terraform apply`.

## Notes

- `disk_type = "custom_shared"` looks up the `"shared.custom"` disk offering. That offering **must** be included in `disk_offerings`.
- `disk_type = "custom_local"` looks up the `"local.custom"` disk offering. That offering **must** be included in `disk_offerings`.
- Provider credentials are **not** configured in this module; pass a configured `cloudstack` provider from the calling stack.
