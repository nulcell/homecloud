# cloudstack-vpc

Creates the homecloud VPC and all VPC network tiers.

## Usage

```hcl
module "vpc" {
  source = "../../modules/cloudstack-vpc"

  zone_id         = "zone-uuid"
  zone_name       = "zone-homecloud"
  account_name    = "homecloud"
  domain_id       = "domain-uuid"
  domain_name     = "homecloud"
  vpc_name        = "homecloud-vpc"
  vpc_cidr        = "10.0.0.0/24"
  vpc_offering_id = "vpc-offering-uuid"
  default_acl_id  = "acl-uuid"  # optional; default_allow ACL UUID

  vpc_networks = {
    "pub-net-1"  = { cidr = "10.0.0.0/26",   gateway = "10.0.0.1",   offering_id = "pub-lb-offering-uuid" }
    "priv-net-1" = { cidr = "10.0.0.64/26",  gateway = "10.0.0.65",  offering_id = "int-lb-offering-uuid" }
    "priv-net-2" = { cidr = "10.0.0.128/26", gateway = "10.0.0.129", offering_id = "int-lb-offering-uuid" }
    "priv-net-3" = { cidr = "10.0.0.192/26", gateway = "10.0.0.193", offering_id = "int-lb-offering-uuid" }
  }

  # Import existing resources (leave empty to create new)
  existing_vpc_id      = "existing-vpc-uuid"
  existing_network_ids = {
    "pub-net-1"  = "existing-pub-net-1-uuid"
    "priv-net-1" = "existing-priv-net-1-uuid"
    "priv-net-2" = "existing-priv-net-2-uuid"
    "priv-net-3" = "existing-priv-net-3-uuid"
  }
}
```

## Inputs

| Name | Type | Default | Description |
|------|------|---------|-------------|
| `zone_id` | `string` | required | UUID of the CloudStack zone |
| `zone_name` | `string` | required | Name of the CloudStack zone |
| `account_name` | `string` | required | CloudStack account name |
| `domain_id` | `string` | required | UUID of the CloudStack domain |
| `domain_name` | `string` | required | Name of the CloudStack domain |
| `vpc_name` | `string` | required | Name of the VPC |
| `vpc_cidr` | `string` | required | CIDR block for the VPC |
| `vpc_offering_id` | `string` | required | UUID of the VPC offering |
| `vpc_networks` | `map(object)` | required | Network tier name → config map |
| `default_acl_id` | `string` | `""` | UUID of the default_allow ACL to apply to all tiers |
| `existing_vpc_id` | `string` | `""` | Existing VPC UUID for import |
| `existing_network_ids` | `map(string)` | `{}` | Existing network tier UUIDs for import |

## Outputs

| Name | Description |
|------|-------------|
| `vpc_id` | UUID of the VPC |
| `network_ids` | Map of network tier key → UUID |
| `pub_net_1_id` | UUID of pub-net-1 |
| `priv_net_1_id` | UUID of priv-net-1 |
| `priv_net_2_id` | UUID of priv-net-2 |
| `priv_net_3_id` | UUID of priv-net-3 |

## Import

### Look up existing resource IDs

```bash
# Get VPC ID
cmk -p homecloud-admin list vpcs name="homecloud-vpc" account=homecloud \
  | jq -r '.vpc[0].id'

# Get network tier IDs
cmk -p homecloud-admin list networks account=homecloud \
  | jq -r '.network[] | "\(.name) \(.id)"'

# Get default_allow ACL ID (needed for default_acl_id variable)
VPC_ID=$(cmk -p homecloud-admin list vpcs name="homecloud-vpc" | jq -r '.vpc[0].id')
cmk -p homecloud-admin list networkacllists name="default_allow" vpcid="$VPC_ID" \
  | jq -r '.networkacllist[0].id'
```

### Import via Terraform variables

Set `existing_vpc_id` and `existing_network_ids` in your `terragrunt.hcl` inputs, then run `terragrunt apply`.

## Notes

- When the CloudStack global setting `vpc.tier.name.prepend = true` is enabled (default in this environment), CloudStack stores network names as `<vpc_name>_<tier_key>` (e.g. `homecloud-vpc_pub-net-1`). Set `name = each.key` in this module; the prepend happens server-side.
- The `default_acl_id` variable must be looked up after the VPC is created, as ACL lists are VPC-scoped.
