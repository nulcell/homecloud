# cloudstack-account

Creates a CloudStack account (type: `DomainAdmin`) within a specified domain, using `cloudmonkey` CLI via `null_resource`. The CloudStack Terraform provider v0.6 does not include a native `cloudstack_account` resource, so `cmk create account` is used instead.

Account creation is **idempotent**: the provisioner checks whether the account already exists before attempting to create it, so re-running `terraform apply` is safe.

> **API keys**: After account creation, CloudStack API keys for the new account must be generated separately. See the [Post-Creation Steps](#post-creation-steps) section below.

---

## Usage

```hcl
module "account" {
  source = "../../catalog/modules/cloudstack-account"

  account_name = "homecloud-admin"
  domain_id    = module.domain.domain_id
  domain_name  = module.domain.domain_name
  timezone     = "Europe/Amsterdam"
  cmk_profile  = "admin"

  # These values are typically read from 1Password by the calling stack
  # and passed in as plain strings.
  email     = "admin@homecloud.internal"
  firstname = "Homecloud"
  lastname  = "Admin"
  password  = var.account_password  # sensitive
  username  = "homecloud-admin"
}
```

### Reading credentials from 1Password in the calling stack

```hcl
data "onepassword_item" "account_creds" {
  vault = "homecloud"
  title = "cloudstack-admin-account"
}

module "account" {
  source    = "../../catalog/modules/cloudstack-account"
  # ...
  email     = data.onepassword_item.account_creds.username  # or a custom field
  password  = data.onepassword_item.account_creds.password
  # ...
}
```

---

## Inputs

| Name | Type | Description | Default | Required |
|------|------|-------------|---------|----------|
| `account_name` | `string` | CloudStack account name to create | — | ✅ |
| `domain_id` | `string` | UUID of the CloudStack domain in which to create the account | — | ✅ |
| `domain_name` | `string` | Name of the CloudStack domain (used as cmk parameter) | — | ✅ |
| `email` | `string` | Email address for the account's admin user | — | ✅ |
| `firstname` | `string` | First name for the account's admin user | — | ✅ |
| `lastname` | `string` | Last name for the account's admin user | — | ✅ |
| `password` | `string` (sensitive) | Password for the account's admin user | — | ✅ |
| `username` | `string` | Username for the account's admin user | — | ✅ |
| `timezone` | `string` | Timezone for the account's users | `"Europe/Amsterdam"` | ❌ |
| `cmk_profile` | `string` | Cloudmonkey profile name with admin credentials | `"admin"` | ❌ |

---

## Outputs

| Name | Type | Description |
|------|------|-------------|
| `account_name` | `string` | Name of the CloudStack account |
| `domain_id` | `string` | UUID of the domain the account belongs to |

---

## Post-Creation Steps

### Generate API keys for the new account

After account creation, generate an API key/secret pair for the admin user:

```sh
# 1. Find the user ID for the new account
USER_ID=$(cmk -p admin list users \
  account=homecloud-admin \
  domainid=<domain_id> \
  --output text --filter id | head -1)

# 2. Register (or regenerate) API keys
cmk -p admin create userkeys userid="$USER_ID"
```

Save the returned `apikey` and `secretkey` to 1Password:

```sh
op item edit "cloudstack-homecloud-admin" \
  "api_key[password]=$(cmk ... | jq -r '.userkeys.apikey')" \
  "api_secret[password]=$(cmk ... | jq -r '.userkeys.secretkey')" \
  --vault homecloud
```

### Import Instructions

Because the account is managed via `null_resource`, there is no Terraform resource to import. The `null_resource` has a stable trigger (`account_name` + `domain_id`) so it creates the account on first apply and never re-runs unless those values change.

To verify the account exists without running Terraform:

```sh
cmk -p admin list accounts name=homecloud-admin domainid=<domain_id>
```
