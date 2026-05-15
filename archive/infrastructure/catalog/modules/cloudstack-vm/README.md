# cloudstack-vm

Deploys a generic CloudStack VM instance. Used for general-purpose VPS VMs, Tailscale routers, and Talos Kubernetes nodes.

## Usage

```hcl
module "vps" {
  source = "../../modules/cloudstack-vm"

  name         = "homecloud-vps"
  zone_id      = "zone-uuid"
  zone_name    = "zone-homecloud"
  account_name = "homecloud"
  domain_id    = "domain-uuid"
  template_id  = "ubuntu-template-uuid"
  offering_id  = "gen.xlarge"  # name or UUID
  root_disk_size = 30
  network_ids  = ["priv-net-1-uuid"]
  keypair_name = "nulcell"
  userdata_id  = "userdata-uuid"  # from CloudStack userdata registry
  enable       = true

  # Import existing VM (leave empty to create new)
  existing_vm_id = "existing-vm-uuid"
}
```

### Multi-NIC VM (e.g. Tailscale router)

```hcl
module "vpn_router" {
  source = "../../modules/cloudstack-vm"

  name        = "homecloud-vpn-router"
  template_id = "ubuntu-template-uuid"
  offering_id = "gen.tiny"
  network_ids = [
    "pub-net-1-uuid",
    "priv-net-1-uuid",
    "priv-net-2-uuid",
    "priv-net-3-uuid",
    "iso-net-shared-uuid",
  ]
  userdata_id      = "tailscale-userdata-uuid"
  userdata_details = {
    tailscale_auth_key   = "tskey-auth-..."
    network_router_cidr  = "10.0.0.0/15"
  }
  # ...
}
```

## Inputs

| Name | Type | Default | Description |
|------|------|---------|-------------|
| `name` | `string` | required | VM name |
| `display_name` | `string` | `""` | Display name (defaults to name) |
| `zone_id` | `string` | required | UUID of the CloudStack zone |
| `zone_name` | `string` | required | Name of the CloudStack zone |
| `account_name` | `string` | required | CloudStack account name |
| `domain_id` | `string` | required | UUID of the CloudStack domain |
| `template_id` | `string` | required | UUID of the VM template |
| `offering_id` | `string` | required | UUID or name of the service offering |
| `root_disk_size` | `number` | `20` | Root disk size in GB |
| `network_ids` | `list(string)` | required | Ordered list of network UUIDs (first = primary NIC) |
| `keypair_name` | `string` | `""` | SSH keypair name to inject |
| `userdata_id` | `string` | `""` | Pre-registered CloudStack userdata UUID |
| `userdata_details` | `map(string)` | `{}` | Userdata template substitution params (sensitive) |
| `user_data_base64` | `string` | `""` | Raw base64 user_data (overrides userdata_id; sensitive) |
| `enable` | `bool` | `true` | Set false to skip VM creation |
| `existing_vm_id` | `string` | `""` | Existing VM UUID for import |
| `tags` | `map(string)` | `{}` | Resource tags |

## Outputs

| Name | Description |
|------|-------------|
| `vm_id` | UUID of the VM instance |
| `vm_name` | Name of the VM |
| `private_ip` | Primary private IP address |

## Import

### Look up existing VM ID

```bash
# Get VM ID by name
cmk -p homecloud-admin list virtualmachines name="homecloud-vps" account=homecloud \
  | jq -r '.virtualmachine[0].id'

# Get VPS VM
cmk -p homecloud-admin list virtualmachines name="homecloud-vps" account=homecloud \
  | jq -r '.virtualmachine[] | "\(.name) \(.id) \(.state)"'
```

### Import via Terraform variable

Set `existing_vm_id` in your `terragrunt.hcl` inputs, then run `terragrunt apply`.

## Notes

- The first element of `network_ids` becomes the primary NIC (`cloudstack_instance.network_id`). Additional networks are attached via `cloudstack_nic` resources.
- `user_data_base64` takes precedence over `userdata_id` when both are set (use for Talos machine configs).
- `user_data_id` and `user_data_details` support requires CloudStack TF provider that exposes these attributes on `cloudstack_instance`.
- `user_data` changes are ignored after initial creation (`lifecycle.ignore_changes`).
