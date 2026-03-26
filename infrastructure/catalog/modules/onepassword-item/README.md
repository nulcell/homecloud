# onepassword-item

Reads a secret item from 1Password and optionally writes fields back. Used to:

1. Read CloudStack admin API credentials at plan time.
2. Write generated credentials (Talos configs, kubeconfigs) back to 1Password.

## Usage

### Read-only (no `fields`)

```hcl
module "cs_admin_creds" {
  source = "../../modules/onepassword-item"
  vault  = "homecloud"
  title  = "CloudStack - admin"
}

# Access a field:
# module.cs_admin_creds.item.fields["api key"]
```

### Write fields back

```hcl
module "kubeconfig_store" {
  source = "../../modules/onepassword-item"
  vault  = "homecloud"
  title  = "Talos - kubeconfig"

  fields = {
    kubeconfig = local.kubeconfig_yaml
    talosconfig = local.talos_config_yaml
  }
}
```

## Inputs

| Name | Type | Default | Description |
|------|------|---------|-------------|
| `vault` | string | required | 1Password vault name or UUID. |
| `title` | string | required | Item title to read (and optionally update). |
| `fields` | `map(string)` | `{}` | Fields to write (label → value). Empty = read-only. |

## Outputs

| Name | Type | Description |
|------|------|-------------|
| `item` | sensitive object | Full `onepassword_item` data source object. |
| `fields` | sensitive map | All fields from the item. |

## Authentication

The 1Password provider authenticates via:
- `OP_SERVICE_ACCOUNT_TOKEN` environment variable (CI/CD), or
- An active `op` CLI session (`op signin`).

No credentials are hardcoded in HCL.

## Provider

This module requires the `onepassword` provider (`1Password/onepassword ~> 3.3`). Pass it in from the calling stack — do not configure `providers.tf` in this module.
