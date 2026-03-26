# cloudstack-network

Creates and manages a standalone isolated network (not VPC-attached). Used for `iso-net-shared` and similar shared isolated networks.

## Usage

```hcl
module "isolated_network" {
  source = "../../modules/cloudstack-network"

  zone_id             = "zone-uuid"
  zone_name           = "zone-homecloud"
  account_name        = "homecloud"
  domain_id           = "domain-uuid"
  name                = "iso-net-shared"
  display_text        = "Homecloud Shared Isolated Network"
  cidr                = "10.1.1.0/24"
  gateway             = "10.1.1.1"
  network_offering_id = "isolated-offering-uuid"

  # Import existing resource (leave empty to create new)
  existing_network_id = "existing-network-uuid"
}
```

## Inputs

| Name | Type | Default | Description |
|------|------|---------|-------------|
| `zone_id` | `string` | required | UUID of the CloudStack zone |
| `zone_name` | `string` | required | Name of the CloudStack zone |
| `account_name` | `string` | required | CloudStack account name |
| `domain_id` | `string` | required | UUID of the CloudStack domain |
| `name` | `string` | required | Name of the isolated network |
| `display_text` | `string` | required | Display text / description |
| `cidr` | `string` | required | CIDR block (e.g. 10.1.1.0/24) |
| `gateway` | `string` | required | Gateway IP address |
| `netmask` | `string` | `"255.255.255.0"` | Netmask |
| `network_offering_id` | `string` | required | UUID of the network offering |
| `existing_network_id` | `string` | `""` | Existing network UUID for import |

## Outputs

| Name | Description |
|------|-------------|
| `network_id` | UUID of the isolated network |
| `network_name` | Name of the isolated network |
| `cidr` | CIDR block of the network |
| `gateway` | Gateway IP of the network |

## Import

### Look up existing resource IDs

```bash
# Get isolated network ID
cmk -p homecloud-admin list networks name="iso-net-shared" account=homecloud \
  | jq -r '.network[0].id'

# Get network offering ID
cmk -p homecloud-admin list networkofferings name="isolated.core-redundant" \
  | jq -r '.networkoffering[0].id'
```

### Import via Terraform variable

Set `existing_network_id` in your `terragrunt.hcl` inputs, then run `terragrunt apply`.
