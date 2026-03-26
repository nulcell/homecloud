# cloudstack-shared-filesystem

Creates CloudStack SharedFileSystem resources (NFS-backed VMs) using `cmk createSharedFileSystem`.

## Notes

There is no native Terraform resource for CloudStack SharedFileSystems. This module uses `null_resource` + `local-exec` to invoke the CloudStack API via `cmk`.

**Important limitations:**

- `null_resource` does **not** support `lifecycle { prevent_destroy }`.
- Removing an entry from the `filesystems` map will **destroy the null_resource** on next apply, losing state tracking. The actual SharedFileSystem in CloudStack will **not** be automatically deleted — you must run `cmk deleteSharedFileSystem` manually.
- Use `enable = false` to temporarily disable all filesystem creation without removing map entries.
- The provisioner re-runs only when the filesystem config changes (trigger: sha256 of the config).

## Usage

```hcl
module "shared_filesystems" {
  source = "../../modules/cloudstack-shared-filesystem"

  account_name = "homecloud"
  domain_id    = "domain-uuid"
  zone_id      = "zone-uuid"
  zone_name    = "zone-homecloud"
  enable       = true

  filesystems = {
    "media-server-fs-config" = {
      size_gb          = 10
      service_offering = "mem.small"
      disk_offering    = "shared.custom"
      network_name     = "homecloud-vpc_pub-net-1"
    }
    "media-server-fs-data" = {
      size_gb          = 500
      service_offering = "mem.small"
      disk_offering    = "shared.custom"
      network_name     = "homecloud-vpc_pub-net-1"
    }
  }
}
```

## Inputs

| Name | Type | Default | Description |
|------|------|---------|-------------|
| `account_name` | `string` | required | CloudStack account name |
| `domain_id` | `string` | required | UUID of the CloudStack domain |
| `zone_id` | `string` | required | UUID of the CloudStack zone |
| `zone_name` | `string` | required | Name of the CloudStack zone |
| `cmk_profile` | `string` | `"homecloud-admin"` | CloudMonkey CLI profile |
| `enable` | `bool` | `true` | Set false to skip all creation |
| `filesystems` | `map(object)` | `{}` | Map of filesystem name → config |

### `filesystems` object fields

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `size_gb` | `number` | required | Size in GB |
| `service_offering` | `string` | required | Service offering name (e.g. `mem.small`) |
| `disk_offering` | `string` | required | Disk offering name (e.g. `shared.custom`) |
| `network_name` | `string` | required | Full network name (e.g. `homecloud-vpc_pub-net-1`) |
| `filesystem` | `string` | `"XFS"` | Filesystem type |
| `provider_name` | `string` | `"SHAREDFSVM"` | SharedFileSystem provider |

## Outputs

| Name | Description |
|------|-------------|
| `filesystem_names` | List of filesystem names managed by this module |

## Query existing filesystems

```bash
# List shared filesystems
cmk -p homecloud-admin list sharedfilesystems account=homecloud \
  | jq -r '.sharedfilesystem[] | "\(.name) \(.id) \(.state)"'
```
