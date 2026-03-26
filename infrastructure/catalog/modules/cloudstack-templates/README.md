# cloudstack-templates

Registers OS templates and ISOs in a CloudStack zone. All templates have `lifecycle { prevent_destroy = true }` — they are never automatically destroyed.

## Usage

```hcl
module "templates" {
  source    = "../../modules/cloudstack-templates"
  zone_id   = module.zone.zone_id
  zone_name = var.zone_name

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
        keyboard         = "us"
        rootdisksize     = "10"
        "guest.cpu.mode" = "host-model"
      }
    }
  }

  isos = {
    "windows-server-2025" = {
      name         = "windows-server-2025"
      display_text = "Windows Server 2025 ISO"
      url          = "https://..."
      os_type      = "Windows Server 2025"
      bootable     = true
      is_featured  = true
    }
  }
  enable_isos = true

  existing_template_ids = {
    "ubuntu-24.04" = "abc-123-uuid"
  }
}
```

## Inputs

| Name | Type | Default | Description |
|------|------|---------|-------------|
| `zone_id` | string | required | UUID of the CloudStack zone. |
| `zone_name` | string | required | Name of the CloudStack zone. |
| `templates` | `map(object)` | `{}` | Templates to register. |
| `isos` | `map(object)` | `{}` | ISOs to register (via cmk CLI). |
| `enable_isos` | bool | `true` | Set to `false` to skip ISO registration. |
| `existing_template_ids` | `map(string)` | `{}` | Template key → UUID for import. |
| `existing_iso_ids` | `map(string)` | `{}` | Informational only; ISOs use null_resource. |

### `templates` object fields

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `name` | string | required | CloudStack template name. |
| `display_text` | string | required | Human-readable description. |
| `url` | string | required | Download URL for the template image. |
| `format` | string | required | `"QCOW2"`, `"RAW"`, `"VHD"`, etc. |
| `hypervisor` | string | required | `"KVM"` etc. |
| `os_type` | string | required | CloudStack OS type string (e.g., `"Ubuntu 24.04"`). |
| `is_featured` | bool | `false` | Show in featured templates list. |
| `details` | `map(string)` | `{}` | Extra template details (keyboard, rootdisksize, etc.). |

## Outputs

| Name | Description |
|------|-------------|
| `template_ids` | Map of template key → UUID. |
| `iso_ids` | Always `{}` — ISOs are managed via null_resource (no state tracking). |

## Importing pre-existing templates

Look up template UUIDs with cloudmonkey:

```bash
# Templates
cmk -p admin list templates templatefilter=all \
  | jq -r '.template[] | "\(.name): \(.id)"'

# ISOs
cmk -p admin list isos isofilter=all \
  | jq -r '.iso[] | "\(.name): \(.id)"'
```

Pass template UUIDs via `existing_template_ids`. ISOs cannot be imported into `null_resource` state.

## Notes on `prevent_destroy`

Templates have `lifecycle { prevent_destroy = true }`. To decommission a template:

1. Stop all VMs that use this template.
2. Remove the template entry from `templates` map.
3. Remove the corresponding entry from `existing_template_ids`.
4. Run `terraform apply` — Terraform will error if prevent_destroy is still set.
5. Manually deregister the template:
   ```bash
   cmk -p admin delete template id=<uuid> zoneid=<zone_uuid>
   ```

To update a template URL (new version), taint the resource and re-apply:
```bash
terraform taint 'module.templates.cloudstack_template.this["ubuntu-24.04"]'
terraform apply
```

> **ISOs**: `null_resource` does not support `prevent_destroy`. Protect ISOs by never removing their entries from the `isos` map.
