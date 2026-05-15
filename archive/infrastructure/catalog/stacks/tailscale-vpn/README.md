# tailscale-vpn

Deploys the `homecloud-vpn-router` Ubuntu VM on all 5 CloudStack networks and
configures it as a Tailscale subnet router.

## Description

This stack:

1. Optionally generates a Tailscale auth key via the `tailscale-key` module
   (when `op_tailscale_ref` is empty), or reads an existing key from 1Password.
2. Deploys a single Ubuntu VM with the given userdata template, passing the
   Tailscale auth key and VPN CIDR as userdata parameters.

The VM joins the Tailscale network on first boot and advertises the `vpn_cidr`
as a subnet route, providing connectivity to all 5 CloudStack networks from
any Tailscale device.

## Usage

```hcl
# terragrunt.hcl inputs
inputs = {
  zone_id             = "uuid-of-zone"
  network_ids         = ["net-1-id", "net-2-id", "net-3-id", "net-4-id", "net-5-id"]
  template_id         = "uuid-of-ubuntu-template"
  compute_offering_id = "uuid-of-service-offering"
  keypair_name        = "nulcell"
  userdata_id         = "uuid-of-userdata-object"
  vpn_cidr            = "10.0.0.0/15"
  vm_name             = "homecloud-vpn-router"
  root_disk_size_gb   = 10

  # Leave empty to generate a fresh key via Tailscale API:
  op_tailscale_ref    = ""

  # Or set to read an existing key from 1Password:
  # op_tailscale_ref  = "Tailscale Token"
}
```

## Inputs

| Name | Type | Description | Default | Required |
|------|------|-------------|---------|----------|
| `cloudstack_api_url` | `string` | CloudStack API endpoint URL. | – | yes |
| `zone_id` | `string` | UUID of the CloudStack zone. | – | yes |
| `zone_name` | `string` | Name of the CloudStack zone. | `"zone-homecloud"` | no |
| `account_name` | `string` | CloudStack account name. | `"homecloud"` | no |
| `domain_id` | `string` | UUID of the CloudStack domain. | `""` | no |
| `network_ids` | `list(string)` | Network UUIDs to attach to the VM. | – | yes |
| `template_id` | `string` | UUID of the Ubuntu VM template. | – | yes |
| `compute_offering_id` | `string` | UUID of the service offering. | – | yes |
| `keypair_name` | `string` | SSH keypair name to inject. | – | yes |
| `userdata_id` | `string` | UUID of the CloudStack userdata object. | – | yes |
| `op_vault` | `string` | 1Password vault name or UUID. | `"homecloud"` | no |
| `op_tailscale_ref` | `string` | 1Password item title for existing Tailscale key. | `""` | no |
| `vpn_cidr` | `string` | Subnet CIDR advertised to Tailscale. | `"10.0.0.0/15"` | no |
| `vm_name` | `string` | Name of the VPN router VM. | `"homecloud-vpn-router"` | no |
| `root_disk_size_gb` | `number` | Root disk size in GB. | `10` | no |
| `existing_vm_id` | `string` | Existing VM UUID to import. | `""` | no |

## Outputs

| Name | Description |
|------|-------------|
| `router_vm_id` | UUID of the VPN router VM. |
| `router_vm_ip` | Primary private IP of the VPN router VM. |

## Notes

- When `op_tailscale_ref = ""`, the `tailscale-key` module generates a fresh one-time
  key via the Tailscale API.  Set `TAILSCALE_API_KEY` in the environment before applying.
- When `op_tailscale_ref` is set to a 1Password item title, the stack reads the key
  from that item's `password` field.  No Tailscale API access is needed.
- The `tailscale` provider is configured automatically from the `TAILSCALE_API_KEY`
  environment variable; no hardcoded credentials are needed.
