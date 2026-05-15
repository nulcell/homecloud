# cloudstack-userdata

Registers user-data scripts in CloudStack for a domain/account using `cmk registerUserData`.

## Notes

The `cloudstack_user_data` resource is not available in CloudStack Terraform provider v0.6.x. This module uses `null_resource` + `local-exec` to call `cmk registerUserData` instead. As a result:

- **UUIDs are not tracked in Terraform state.** The `userdata_ids` output always returns an empty-string map. Callers that need UUIDs at plan time should query CloudStack directly.
- The provisioner re-runs when the script file content (`filesha256`) or `params` change.
- Removing a script from the `scripts` map removes the `null_resource` from state but does **not** automatically unregister the userdata from CloudStack. Run `cmk deleteUserData` manually if needed.

## Usage

```hcl
module "userdata" {
  source = "../../modules/cloudstack-userdata"

  account_name = "homecloud"
  domain_id    = "domain-uuid"

  scripts = {
    "cloud-default" = {
      file   = "/absolute/path/to/cloud-default.yaml"
      params = []
    }
    "tailscale-router-debian" = {
      file   = "/absolute/path/to/tailscale-router-debian.yaml"
      params = ["tailscale_auth_key", "network_router_cidr"]
    }
  }
}
```

## Inputs

| Name | Type | Default | Description |
|------|------|---------|-------------|
| `account_name` | `string` | required | CloudStack account name |
| `domain_id` | `string` | required | UUID of the CloudStack domain |
| `cmk_profile` | `string` | `"homecloud-admin"` | CloudMonkey CLI profile |
| `scripts` | `map(object)` | `{}` | Map of userdata name → `{ file, params }` |

## Outputs

| Name | Description |
|------|-------------|
| `userdata_ids` | Map of name → empty string. UUIDs not tracked in state. |

## Import / Query

```bash
# List registered userdata scripts
cmk -p homecloud-admin list userdata account=homecloud \
  | jq -r '.userdata[] | "\(.name) \(.id)"'

# Get a specific userdata ID
cmk -p homecloud-admin list userdata name="cloud-default" account=homecloud \
  | jq -r '.userdata[0].id'
```

## Manual registration (reference)

```bash
HOMECLOUD_DOMAIN_ID=$(cmk -p homecloud-admin list domains name=homecloud | jq -r '.domain[0].id')

cmk -p homecloud-admin registerUserData \
  name="cloud-default" \
  userdata="$(cat cloudstack/compute/cloud-init/cloud-default.yaml | base64)" \
  account=homecloud \
  domainid="$HOMECLOUD_DOMAIN_ID"

cmk -p homecloud-admin registerUserData \
  name="tailscale-router-debian" \
  userdata="$(cat cloudstack/compute/cloud-init/tailscale-router-debian.yaml | base64)" \
  account=homecloud \
  domainid="$HOMECLOUD_DOMAIN_ID" \
  "params=tailscale_auth_key,network_router_cidr"
```
