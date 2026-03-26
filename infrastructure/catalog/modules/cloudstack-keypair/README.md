# cloudstack-keypair

Registers a domain-scoped SSH keypair in CloudStack from a public key (typically stored in 1Password).

## Usage

```hcl
module "keypair" {
  source = "../../modules/cloudstack-keypair"

  name         = "nulcell"
  public_key   = data.onepassword_item.nulcell.fields["public key"]
  domain_id    = "domain-uuid"
  account_name = "homecloud"

  # Import existing keypair (leave empty to register new)
  existing_keypair_id = "nulcell"  # CloudStack uses keypair name as the import ID
}
```

## Inputs

| Name | Type | Default | Description |
|------|------|---------|-------------|
| `name` | `string` | required | Name of the SSH keypair |
| `public_key` | `string` (sensitive) | required | SSH public key string |
| `domain_id` | `string` | required | UUID of the CloudStack domain |
| `account_name` | `string` | required | CloudStack account name |
| `existing_keypair_id` | `string` | `""` | Keypair name used as import ID |

## Outputs

| Name | Description |
|------|-------------|
| `keypair_name` | Name of the registered SSH keypair |
| `fingerprint` | MD5 fingerprint of the registered public key |

## Import

### Look up existing keypair

```bash
# List keypairs for the homecloud account
cmk -p homecloud-admin list sshkeypairs account=homecloud \
  | jq -r '.sshkeypair[] | "\(.name) \(.fingerprint)"'
```

### Import via Terraform variable

CloudStack uses the keypair **name** as the import ID. Set `existing_keypair_id = "nulcell"` in your `terragrunt.hcl` inputs, then run `terragrunt apply`.

### Manual registration (reference)

```bash
HOMECLOUD_DOMAIN_ID=$(cmk -p homecloud-admin list domains name=homecloud | jq -r '.domain[0].id')

cmk -p homecloud-admin register sshkeypair \
  name="nulcell" \
  publickey="$(op read "op://homecloud/nulcell/public key")" \
  account=homecloud \
  domainid="$HOMECLOUD_DOMAIN_ID"
```
