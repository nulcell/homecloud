# cloudstack-domain

Creates and manages a CloudStack domain with per-account resource limits.

- **`cloudstack_domain`** — creates the domain with a custom network domain suffix; supports import for pre-existing domains
- **`cloudstack_limit`** — sets per-account resource limits (VMs, IPs, volumes, CPU, memory, etc.) within the domain

---

## Usage

```hcl
module "domain" {
  source = "../../catalog/modules/cloudstack-domain"

  domain_name    = "homecloud"
  domain_network = "homecloud.internal"
  account_name   = "homecloud-admin"

  # CloudStack resourcetype integers:
  #  0=user_vm  1=public_ip  2=volume  3=snapshot  4=template
  #  6=network  7=vpc  8=cpu  9=memory(MiB)  10=primary_storage(GiB)  11=secondary_storage(GiB)
  resource_limits = {
    "0"  = 50    # VMs
    "1"  = 20    # Public IPs
    "2"  = 100   # Volumes
    "8"  = 200   # CPU cores
    "9"  = 512000 # Memory MiB (500 GiB)
    "10" = 5000  # Primary storage GiB
    "11" = 1000  # Secondary storage GiB
  }

  # Omit or leave empty to create a new domain
  existing_domain_id = ""
}
```

### Importing a pre-existing domain

```hcl
module "domain" {
  source = "../../catalog/modules/cloudstack-domain"
  # ...
  existing_domain_id = "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
}
```

---

## Inputs

| Name | Type | Description | Default | Required |
|------|------|-------------|---------|----------|
| `domain_name` | `string` | Name of the CloudStack domain to create or manage | — | ✅ |
| `domain_network` | `string` | Network domain suffix, e.g. `homecloud.internal` | — | ✅ |
| `account_name` | `string` | Account name within the domain to which resource limits apply | — | ✅ |
| `resource_limits` | `map(number)` | Map of CloudStack `resourcetype` integer (as string key) → maximum value | — | ✅ |
| `existing_domain_id` | `string` | Existing domain UUID for import; leave empty to create a new domain | `""` | ❌ |

### CloudStack `resourcetype` Reference

| Key | Resource |
|-----|----------|
| `0` | User VMs |
| `1` | Public IPs |
| `2` | Volumes |
| `3` | Snapshots |
| `4` | Templates |
| `6` | Networks |
| `7` | VPCs |
| `8` | CPU cores |
| `9` | Memory (MiB) |
| `10` | Primary storage (GiB) |
| `11` | Secondary storage (GiB) |

---

## Outputs

| Name | Type | Description |
|------|------|-------------|
| `domain_id` | `string` | UUID of the CloudStack domain |
| `domain_name` | `string` | Name of the CloudStack domain |

---

## Import Instructions

### Domain (`cloudstack_domain`)

1. Find the existing domain UUID:
   ```sh
   cmk -p admin list domains name=homecloud | jq -r '.domain[0].id'
   # Or using cmk text output:
   cmk -p admin list domains name=homecloud --output text --filter id
   ```

2. Pass the UUID as `existing_domain_id`:
   ```hcl
   existing_domain_id = "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
   ```

3. Run `terraform plan` (import block activates when UUID is non-empty), then `terraform apply`.

### Resource Limits (`cloudstack_limit`)

Resource limits do not have standalone CloudStack UUIDs to import — the Terraform provider manages them by account+domain+resourcetype tuple. If limits already exist, Terraform will update them in place on the first `apply`.
