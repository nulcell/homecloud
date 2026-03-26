# cloudstack-zone

Manages zone-level infrastructure for a pre-existing CloudStack zone:

- **Physical networks** — created and enabled via `cmk` (`null_resource`)
- **Pod** — created via `cmk` (`null_resource`)
- **KVM Cluster** — added via `cmk` (`null_resource`)
- **KVM Hosts** — added via `cmk` (`null_resource`)
- **Primary Storage Pools (NFS)** — managed as native `cloudstack_storage_pool` resources with import support
- **Secondary Storage / Image Stores** — added via `cmk` (`null_resource`)

The zone itself must already exist; it is looked up by name via `data "cloudstack_zone"`.

---

## Usage

```hcl
module "zone" {
  source = "../../catalog/modules/cloudstack-zone"

  zone_name   = "homecloud-zone"
  cmk_profile = "admin"

  physical_networks = {
    "Management Network" = {
      isolation_method = "VLAN"
      traffic_types    = ["Management", "Storage"]
    }
    "Guest Network" = {
      isolation_method = "VLAN"
      traffic_types    = ["Guest"]
      vlan_range       = "100-200"
    }
    "Public Network" = {
      isolation_method = "VLAN"
      traffic_types    = ["Public"]
      public_ip_range = {
        gateway  = "192.168.1.1"
        netmask  = "255.255.255.0"
        start_ip = "192.168.1.100"
        end_ip   = "192.168.1.200"
        vlan     = "untagged"
      }
    }
  }

  pod = {
    name     = "homecloud-pod"
    gateway  = "10.0.0.1"
    netmask  = "255.255.255.0"
    start_ip = "10.0.0.10"
    end_ip   = "10.0.0.50"
  }

  cluster = {
    name       = "homecloud-cluster"
    hypervisor = "KVM"
  }

  hosts = {
    "10.0.0.11" = { username = "root" }
    "10.0.0.12" = { username = "root" }
  }

  primary_storage_pools = {
    "primary-nfs" = {
      server = "10.0.0.5"
      path   = "/export/primary"
    }
  }

  secondary_storage = {
    "secondary-nfs" = {
      server = "10.0.0.5"
      path   = "/export/secondary"
    }
  }

  # Provide UUIDs to import pre-existing storage pools
  existing_storage_pool_ids = {
    "primary-nfs" = "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
  }
}
```

---

## Inputs

| Name | Type | Description | Default | Required |
|------|------|-------------|---------|----------|
| `zone_name` | `string` | Name of the pre-existing CloudStack zone | — | ✅ |
| `physical_networks` | `map(object)` | Map of physical network name → config (isolation_method, traffic_types, vlan_range, public_ip_range) | — | ✅ |
| `pod` | `object` | Pod config: name, gateway, netmask, start_ip, end_ip | — | ✅ |
| `cluster` | `object` | Cluster config: name, hypervisor | — | ✅ |
| `hosts` | `map(object)` | Map of host IP → `{ username }` | — | ✅ |
| `primary_storage_pools` | `map(object)` | Map of pool name → `{ server, path }` for NFS primary storage | — | ✅ |
| `secondary_storage` | `map(object)` | Map of image store name → `{ server, path }` for NFS secondary storage | — | ✅ |
| `cmk_profile` | `string` | Cloudmonkey profile name with admin credentials | `"admin"` | ❌ |
| `existing_storage_pool_ids` | `map(string)` | Map of pool name → existing UUID for `cloudstack_storage_pool` import | `{}` | ❌ |

---

## Outputs

| Name | Type | Description |
|------|------|-------------|
| `zone_id` | `string` | UUID of the CloudStack zone |
| `zone_name` | `string` | Name of the CloudStack zone |
| `primary_storage_pool_ids` | `map(string)` | Map of pool name → UUID for primary storage pools |
| `pod_resource_id` | `string` | Terraform null_resource ID for the pod (not the CloudStack UUID) |
| `cluster_resource_id` | `string` | Terraform null_resource ID for the cluster (not the CloudStack UUID) |

> **Note on pod_id / cluster_id**: Because these are created via `null_resource`, the CloudStack UUIDs are not captured in Terraform state. After the first apply, retrieve them with:
> ```sh
> cmk -p admin list pods zoneid=<zone_id> name=<pod_name> --output text --filter id
> cmk -p admin list clusters zoneid=<zone_id> clustername=<cluster_name> --output text --filter id
> ```

---

## Import Instructions

### Primary Storage Pools (`cloudstack_storage_pool`)

1. List existing storage pools to find their UUIDs:
   ```sh
   cmk -p admin list storagepools zoneid=<zone_id>
   # Or filter by name:
   cmk -p admin list storagepools name=<pool_name> --output text --filter id
   ```

2. Pass the UUID(s) via `existing_storage_pool_ids`:
   ```hcl
   existing_storage_pool_ids = {
     "primary-nfs" = "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
   }
   ```

3. Run `terraform plan` to verify the import block targets the correct resource, then `terraform apply`.

### null_resource resources (physical networks, pod, cluster, hosts, secondary storage)

`null_resource` is stateless — no import is needed. These provisioners run once when the resource is first created and re-run only when their `triggers` change.
