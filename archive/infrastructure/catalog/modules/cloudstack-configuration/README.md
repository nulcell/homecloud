# cloudstack-configuration

Applies CloudStack global configuration settings via the `updateConfiguration` API. There is no native Terraform resource for these settings, so each key–value pair is managed by a `null_resource` that executes `cmk update configuration` via `local-exec`.

> **Important**: This module runs `cmk` commands against the live CloudStack management server during **both `plan` and `apply`**. Ensure `cmk` is installed, the profile is configured, and the management server is reachable before running Terraform.

---

## Usage

```hcl
module "cs_config" {
  source = "../../catalog/modules/cloudstack-configuration"

  cmk_profile = "admin"

  global_settings = {
    # Networking
    "network.gc.interval"                  = "600"
    "network.gc.wait"                      = "600"

    # Guest VLAN range used across the zone
    "guest.vlan.bits"                       = "12"

    # VM console
    "novnc.enabled"                         = "true"

    # Storage
    "storage.cleanup.interval"              = "86400"
    "storage.overprovisioning.factor"       = "2.0"

    # Expunge / reclaim
    "expunge.delay"                         = "60"
    "expunge.interval"                      = "60"
    "expunge.workers"                       = "3"

    # Capacity
    "cluster.cpu.allocated.capacity.disablethreshold"  = "1.0"
    "cluster.memory.allocated.capacity.disablethreshold" = "1.0"
  }
}
```

---

## Settings Managed by This Module

The module is generic — it accepts any key → value map. Typical settings applied to a homecloud CloudStack deployment include:

| Key | Example Value | Description |
|-----|---------------|-------------|
| `network.gc.interval` | `600` | Interval (s) between network garbage-collection runs |
| `network.gc.wait` | `600` | Wait (s) before GC removes a network |
| `guest.vlan.bits` | `12` | Number of bits used for guest VLANs |
| `novnc.enabled` | `true` | Enable noVNC console proxy |
| `storage.cleanup.interval` | `86400` | Storage GC interval (s) |
| `storage.overprovisioning.factor` | `2.0` | Thin-provisioning multiplier |
| `expunge.delay` | `60` | Delay (s) before VM expunge |
| `expunge.interval` | `60` | Interval (s) between expunge checks |
| `expunge.workers` | `3` | Worker threads for expunge |
| `cluster.cpu.allocated.capacity.disablethreshold` | `1.0` | CPU over-allocation threshold (disable at 100%) |
| `cluster.memory.allocated.capacity.disablethreshold` | `1.0` | Memory over-allocation threshold |

Any valid CloudStack global setting key accepted by `updateConfiguration` can be passed.

---

## Inputs

| Name | Type | Description | Default | Required |
|------|------|-------------|---------|----------|
| `global_settings` | `map(string)` | Map of CloudStack configuration key → value to apply via updateConfiguration API | — | ✅ |
| `cmk_profile` | `string` | Cloudmonkey profile name with admin credentials | `"admin"` | ❌ |

---

## Outputs

| Name | Type | Description |
|------|------|-------------|
| `applied_settings` | `map(string)` | Echo of all `global_settings` that were applied |

---

## Import Instructions

`null_resource` is stateless — there is nothing to import. If you need to re-apply all settings (e.g. after a `terraform state rm`), simply re-run `terraform apply`.

To verify a setting was applied on the CloudStack side:

```sh
cmk -p admin list configurations name=<setting_key>
```
