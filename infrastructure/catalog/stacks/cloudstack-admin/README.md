# cloudstack-admin stack

Admin-scope Terraform stack for the homecloud CloudStack infrastructure. This is the **only** stack that runs with CloudStack root admin credentials.

## What it manages

| Resource group | Module | Notes |
|---|---|---|
| Global configuration | `cloudstack-configuration` | ~30 settings via updateConfiguration API |
| Zone infrastructure | `cloudstack-zone` | Zone data-source lookup, physical networks, pod, cluster, hosts, NFS storage |
| Domain + resource limits | `cloudstack-domain` | `homecloud` domain + 17 resource limits |
| Account | `cloudstack-account` | `homecloud` account created via cmk |
| Disk / compute / network / VPC offerings | `cloudstack-offerings` | All offerings; all imported from existing CloudStack |
| Templates + ISOs | `cloudstack-templates` | Ubuntu 24.04, Debian 12, Talos v1.12.6; lifecycle prevent_destroy |

## Prerequisites

### 1Password

Ensure two 1Password items exist in the configured vault:

| Item title | Required fields |
|---|---|
| `CloudStack - admin` | `api key`, `secret key` |
| `CloudStack - homecloud` (configurable) | `email`, `First name`, `Last name`, `password`, `username` |

Authenticate before running Terraform:

```bash
# Option A: service account (CI/CD)
export OP_SERVICE_ACCOUNT_TOKEN=<token>

# Option B: interactive CLI session
op signin
```

### cloudmonkey (`cmk`)

The zone, account, and configuration modules use `cmk` for resources not covered by the CloudStack Terraform provider. Configure a profile:

```bash
cmk set profile admin
cmk set url http://<cloudstack-host>:8080/client/api
cmk set apikey <admin-api-key>
cmk set secretkey <admin-secret-key>
```

## Deployment

### First deploy (existing infrastructure)

All resources are pre-existing. Populate `existing_*_ids` maps in the Terragrunt inputs, then run:

```bash
terragrunt apply
```

Terraform will import existing resources before applying any changes.

### Subsequent deploys

```bash
terragrunt plan
terragrunt apply
```

## Import workflow

Look up existing resource UUIDs:

```bash
# Disk offerings
cmk -p admin list diskofferings | jq -r '.diskoffering[] | "\(.name): \(.id)"'

# Service offerings
cmk -p admin list serviceofferings | jq -r '.serviceoffering[] | "\(.name): \(.id)"'

# Network offerings
cmk -p admin list networkofferings | jq -r '.networkoffering[] | "\(.name): \(.id)"'

# VPC offerings
cmk -p admin list vpcofferings | jq -r '.vpcoffering[] | "\(.name): \(.id)"'

# Templates
cmk -p admin list templates templatefilter=all | jq -r '.template[] | "\(.name): \(.id)"'

# Domain
cmk -p admin list domains | jq -r '.domain[] | "\(.name): \(.id)"'

# Storage pools
cmk -p admin list storagepools | jq -r '.storagepool[] | "\(.name): \(.id)"'
```

Pass UUIDs via `existing_*_ids` maps in `terragrunt.hcl` inputs. The `import {}` blocks in each module handle the rest.

## Outputs consumed by `cloudstack-homecloud`

| Output | Description |
|---|---|
| `zone_id` | CloudStack zone UUID |
| `domain_id` | homecloud domain UUID |
| `network_offering_ids` | All network offering UUIDs |
| `vpc_offering_ids` | All VPC offering UUIDs |
| `isolated_core_offering_id` | `isolated.core-redundant` offering UUID |
| `public_lb_offering_id` | `vpc.core-public-lb` offering UUID |
| `internal_lb_offering_id` | `vpc.core-internal-lb` offering UUID |
| `vpc_offering_id` | `natted.redundant-core` VPC offering UUID |
| `ubuntu_template_id` | Ubuntu 24.04 template UUID |
| `talos_template_id` | Talos v1.12.6 template UUID |
