# cloudstack-homecloud stack

Homecloud domain-scope CloudStack resources. Depends on the `cloudstack-admin` stack (domain, account, offerings, and templates must exist first).

## What this manages

| Resource | Type | Notes |
|----------|------|-------|
| VPC (`homecloud-vpc`, `10.0.0.0/24`) + 4 network tiers | `cloudstack-vpc` module | Imported from existing |
| Isolated network (`iso-net-shared`, `10.1.1.0/24`) | `cloudstack-network` module | Imported from existing |
| SSH keypair (`nulcell`) | `cloudstack-keypair` module | Optional; imported |
| User-data scripts | `cloudstack-userdata` module | `null_resource` + cmk |
| NFS SharedFileSystems | `cloudstack-shared-filesystem` module | `null_resource` + cmk |
| VPS VM (`homecloud-vps`) | `cloudstack-vm` module | Optional |

## Provider authentication

CloudStack API credentials are read from 1Password at plan/apply time via the `onepassword` provider. Set the `OP_SERVICE_ACCOUNT_TOKEN` environment variable or ensure an active `op` CLI session exists.

## Usage (Terragrunt)

This stack is invoked from `live/homecloud/cloudstack-homecloud/terragrunt.hcl`. See that file for all input values.

```bash
cd infrastructure/live/homecloud/cloudstack-homecloud
terragrunt plan
terragrunt apply
```

## Importing existing resources

Set the `existing_*` variables before the first `apply` to import pre-existing CloudStack resources:

```hcl
# In terragrunt.hcl inputs:
existing_vpc_id          = "vpc-uuid-here"
existing_network_ids     = {
  "pub-net-1"  = "net-uuid-1"
  "priv-net-1" = "net-uuid-2"
  "priv-net-2" = "net-uuid-3"
  "priv-net-3" = "net-uuid-4"
}
existing_isolated_net_id = "iso-net-uuid"
existing_keypair_id      = "nulcell"
existing_vps_id          = "vps-vm-uuid"
```

### Look up IDs with cmk

```bash
# VPC
cmk -p homecloud-admin list vpcs name="homecloud-vpc" \
  | jq -r '.vpc[0].id'

# All VPC network tiers
cmk -p homecloud-admin list networks account=homecloud \
  | jq -r '.network[] | select(.vpcid != null) | "\(.name) \(.id)"'

# Isolated network
cmk -p homecloud-admin list networks name="iso-net-shared" account=homecloud \
  | jq -r '.network[0].id'

# SSH keypair (import ID = name)
cmk -p homecloud-admin list sshkeypairs name="nulcell" account=homecloud \
  | jq -r '.sshkeypair[0].name'

# VPS VM
cmk -p homecloud-admin list virtualmachines name="homecloud-vps" account=homecloud \
  | jq -r '.virtualmachine[0].id'

# default_allow ACL (after VPC exists)
VPC_ID=$(cmk -p homecloud-admin list vpcs name="homecloud-vpc" | jq -r '.vpc[0].id')
cmk -p homecloud-admin list networkacllists name="default_allow" vpcid="$VPC_ID" \
  | jq -r '.networkacllist[0].id'
```

## Key variables

| Name | Description |
|------|-------------|
| `cloudstack_api_url` | CloudStack API URL |
| `op_vault` | 1Password vault name |
| `zone_id` | Zone UUID (cloudstack-admin output) |
| `domain_id` | Domain UUID (cloudstack-admin output) |
| `vpc_offering_id` | VPC offering UUID (cloudstack-admin output) |
| `ubuntu_template_id` | Ubuntu 24.04 template UUID (cloudstack-admin output) |
| `enable_vps` | Toggle VPS VM creation |
| `enable_shared_storage` | Toggle NFS filesystem creation |
| `default_acl_id` | UUID of the default_allow ACL (set after first VPC apply) |

## Notes

- **userdata_ids output**: Always returns empty strings because userdata registration uses `null_resource`. To get UUID for a VM's `userdataid`, query CloudStack: `cmk -p homecloud-admin list userdata name=<name> account=homecloud`.
- **Shared filesystem deletion**: Removing an entry from `shared_filesystems` loses state tracking but does **not** delete the CloudStack resource. Run `cmk deleteSharedFileSystem` manually.
- **VPC network naming**: CloudStack prepends the VPC name when `vpc.tier.name.prepend = true`. The stored name is `homecloud-vpc_pub-net-1` etc.
