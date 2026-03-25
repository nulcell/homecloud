# Infrastructure Terragrunt Plan

## Overview

Convert the entire `cloudstack/docs/00-CLI.md` CloudMonkey command set into a fully
deterministic Terragrunt + Terraform stack under `infrastructure/`. The only manual
prerequisite is a running CloudStack management server with admin credentials in
1Password (`op://homecloud/CloudStack - admin/...`).

**Scope excludes:** CloudStack zone/physical network/host setup (already live — these
are imported, not recreated), and the CKS Kubernetes section (replaced entirely by the
Talos + Tailscale router approach below).

---

## Provider Stack

| Provider | Source | Version | Notes |
|---|---|---|---|
| CloudStack | `apache/cloudstack` | `~> 0.6` | v0.6.0 latest stable |
| Tailscale | `tailscale/tailscale` | `~> 0.28` | v0.28.0 |
| 1Password | `1Password/onepassword` | `~> 3.3` | v3.3.1 |
| Talos | `siderolabs/talos` | `~> 0.10` | v0.10.1 (v0.11.0-beta.1 skipped) |
| Helm | `hashicorp/helm` | `~> 3.1` | v3.1.1 |
| Kubernetes | `hashicorp/kubernetes` | `~> 3.0` | v3.0.1 |
| Cloudflare | `cloudflare/cloudflare` | `~> 4.52` | v4.52.7 (v5.x still beta) |
| Local | `hashicorp/local` | `~> 2.7` | v2.7.0 |
| Null | `hashicorp/null` | `~> 3.2` | v3.2.4 |
| Random | `hashicorp/random` | `~> 3.8` | v3.8.1 |
| External | `hashicorp/external` | `~> 2.3` | v2.3.5 |

> Versions last verified: 2026-03-25. Update `.mise.toml` and `root.hcl` together.

### Two CloudStack Provider Aliases

- `cloudstack.admin` — admin API key (`op://homecloud/CloudStack - admin/...`)
  - Used **only** in `catalog/stacks/cloudstack-admin`
- `cloudstack.homecloud` — homecloud-admin API key (`op://homecloud/CloudStack - homecloud-admin/...`)
  - Used in `catalog/stacks/cloudstack-homecloud`, `tailscale-vpn`, `talos-cluster`, `argocd-setup`

---

## Directory Structure

```
infrastructure/
  PLAN.md

  catalog/
    modules/                         ← granular single-concern Terraform modules
      cloudstack-configuration/      ← ~30 global settings (cloudstack_configuration)
      cloudstack-zone/               ← zone, physical networks, pod, cluster, hosts, storage
      cloudstack-domain/             ← domain + resource limits
      cloudstack-account/            ← account creation + API key generation
      cloudstack-offerings/          ← disk/compute/network/VPC offerings (for_each maps)
      cloudstack-templates/          ← image registration (for_each map, prevent_destroy)
      cloudstack-vpc/                ← VPC + public/private subnets + ACLs
      cloudstack-network/            ← isolated networks (iso-net-shared)
      cloudstack-keypair/            ← SSH keypair (domain-scoped, homecloud-admin)
      cloudstack-userdata/           ← user data script registration (homecloud-admin)
      cloudstack-vm/                 ← generic VM module (Talos nodes + Ubuntu VMs)
      cloudstack-shared-filesystem/  ← NFS SharedFileSystems (is_enabled flag)
      tailscale-key/                 ← tailscale_tailnet_key for subnet router VM
      talos-config/                  ← machine secrets, control-plane + worker configs
      kubernetes-bootstrap/          ← Helm: Cilium, CCM, CSI, ArgoCD, cert-manager
      onepassword-item/              ← write generated credentials to 1Password

    stacks/                          ← baseline full infrastructure components
      cloudstack-admin/              ← admin-scope: global config, zone, domain, account,
                                     #   offerings (maps), templates (maps, prevent_destroy)
      cloudstack-homecloud/          ← homecloud-admin scope: VPC, networks, iso-net,
                                     #   keypair, userdata, NFS filesystems
      tailscale-vpn/                 ← subnet router VM (homecloud-vpn-router, Ubuntu 24.04)
      talos-cluster/                 ← parameterised Talos k8s cluster (both clusters reuse this)
      argocd-setup/                  ← ArgoCD + cluster registration (ops cluster only)

  live/
    root.hcl                         ← local state, provider version constraints only
    homecloud/
      account.hcl                    ← env variables (URLs, CIDRs, vault refs, cluster names)
      homecloud.stack.hcl            ← explicit stack: 5 units + dependency graph
      cloudstack-admin/              ← unit 1: admin-scope resources
        terragrunt.hcl
      cloudstack-homecloud/          ← unit 2: homecloud domain resources
        terragrunt.hcl
      tailscale-vpn/                 ← unit 3: subnet router VM
        terragrunt.hcl
      ops-cluster/                   ← unit 4: Talos ops cluster + ArgoCD
        terragrunt.hcl
      workload-cluster/              ← unit 5: Talos workload cluster + cert-manager
        terragrunt.hcl
```

---

## Admin vs Domain Scope Split

The split follows the actual `cloudmonkey` profile used in `00-CLI.md`:

### `cloudstack-admin` stack (admin profile)
- Zone setup, physical networks, pod, KVM cluster, hosts, storage pools
- Domain creation (`homecloud`), account creation (`homecloud-admin`), resource limits
- All offerings: disk, compute, network, VPC — **input as `for_each` maps**
- Templates/images: Ubuntu 24.04, Talos v1.12.6 — **input as `for_each` map**
  - `lifecycle { prevent_destroy = true }` on all template resources
  - Images are **never deleted** even if removed from the input map; requires manual cleanup
- Global configuration settings (~30 `cloudstack_configuration` resources)

### `cloudstack-homecloud` stack (homecloud-admin profile)
- VPC (`homecloud-vpc`, `10.0.0.0/24`) + 4 network tiers
- Isolated network (`iso-net-shared`, `10.1.1.0/24`)
- SSH keypair `nulcell` — domain-scoped (`account=homecloud, domainid=...`)
- User-data scripts: `cloud-default`, `tailscale-router-debian`
- NFS SharedFileSystems: `media-server-fs-config` (10GB), `media-server-fs-data` (500GB)
  — guarded by `enable_shared_storage` flag
- Generates homecloud-admin CloudStack API key → writes to 1Password

---

## Kubernetes Architecture

### Network Topology

```
CloudStack VPC: homecloud-vpc (10.0.0.0/24)
  pub-net-1  (10.0.0.0/26,   vpc.core-public-lb)   ← WORKLOAD cluster nodes
  priv-net-1 (10.0.0.64/26,  vpc.core-internal-lb)  ← VPS, other VMs
  priv-net-2 (10.0.0.128/26, vpc.core-internal-lb)  ← available
  priv-net-3 (10.0.0.192/26, vpc.core-internal-lb)  ← available

Isolated Network: iso-net-shared (10.1.1.0/24, isolated.core-redundant)
  ← OPS cluster nodes (control plane + workers)

Tailscale subnet router VM (homecloud-vpn-router, Ubuntu 24.04):
  Connected to ALL 5 networks above
  Advertises 10.0.0.0/15 into tailnet → operator access to all CloudStack resources
  NOT involved in k8s cluster traffic
```

**Why this topology?** CloudStack VPCs only support one `public-lb` offering subnet per VPC.
Two Talos clusters each needing a public-lb network would require two VPCs. Instead:
- Workload cluster → VPC `pub-net-1` (existing public-lb subnet)
- Ops cluster → `iso-net-shared` isolated network (separate from VPC, already exists)

Both clusters get CloudStack public IPs + LB rules for kube-apiserver access regardless.

### Talos Bootstrap Flow (per cluster)

1. **Acquire CloudStack public IP** (`cloudstack_ipaddress`)
2. **Create CloudStack LB rule** (`k8s-api`, port 6443) on that public IP
3. **Generate Talos machine secrets** (`talos_machine_secrets`)
4. **Generate machine configs** with endpoint = `https://<LB_IP>:6443`
5. **Deploy Talos VMs** with machine config as base64 `user_data`
6. **Assign control plane VMs** to the LB rule
7. **Bootstrap etcd** (`talos_machine_bootstrap`)
8. **Deploy worker VMs** with worker machine config
9. **Retrieve kubeconfig** (`talos_client_configuration`)
10. **Install core Helm charts** (Cilium, CloudStack CCM, CloudStack CSI)
11. **Write talosconfig + kubeconfig** to 1Password via `onepassword-item` module

### Two Clusters

| Cluster | Name | Network | Helm Add-ons |
|---|---|---|---|
| Ops | `homecloud-ops` | `iso-net-shared` (10.1.1.0/24) | Cilium, CCM, CSI, **ArgoCD** |
| Workload | `homecloud-workload` | VPC `pub-net-1` (10.0.0.0/26) | Cilium, CCM, CSI, external-dns, **cert-manager** |

**ArgoCD** (ops cluster) is bootstrapped by Terraform and registers **both** clusters
as managed targets. Application charts in `charts/` are then deployed via GitOps.

### Talos Image

- Schematic: `23ff67af89fd08e5703f919f9b58c5a4a6de2540b1f8ca83379e19321560b1bf`
- Extensions: `btrfs`, `nfs-utils`, `nfsd`, `nfsrahead`, `qemu-guest-agent`
- URL: `https://factory.talos.dev/image/23ff67af.../v1.12.6/cloudstack-amd64.raw.gz`
- ⚠️ CloudStack may reject compressed images — if registration fails, drop `.gz`

---

## Offerings and Images as Maps (Key Design)

All offerings and images use `for_each` over input maps. This means:
- Adding a new offering = add an entry to the map in `terragrunt.hcl`
- The resource key is the offering name (stable, used for imports)
- Images additionally have `lifecycle { prevent_destroy = true }` — VMs may be using them

Example pattern:
```hcl
# In catalog/modules/cloudstack-offerings/main.tf
resource "cloudstack_service_offering" "compute" {
  for_each = var.compute_offerings
  name     = each.key
  # ...each.value fields...
}
```

---

## Secrets Strategy

### Reading from 1Password
| Secret | Path | Used By |
|---|---|---|
| CloudStack admin API key/secret | `op://homecloud/CloudStack - admin/...` | `cloudstack.admin` provider |
| homecloud-admin password | `op://homecloud/CloudStack - homecloud-admin/password` | `cloudstack_account` |
| SSH public key | `op://homecloud/nulcell/public key` | `cloudstack_ssh_keypair` |
| Tailscale auth key | `op://homecloud/Tailscale Token/credential` | Tailscale router VM userdata |

### Writing to 1Password
| Secret | Written By | Item |
|---|---|---|
| homecloud-admin API key | `cloudstack-homecloud` stack | `op://homecloud/CloudStack - homecloud-admin/api_key` |
| ops talosconfig | `onepassword-item` module | `op://homecloud/Talosconfig - homecloud-ops/...` |
| ops kubeconfig | `onepassword-item` module | `op://homecloud/Kubeconfig - homecloud-ops/...` |
| workload talosconfig | `onepassword-item` module | `op://homecloud/Talosconfig - homecloud-workload/...` |
| workload kubeconfig | `onepassword-item` module | `op://homecloud/Kubeconfig - homecloud-workload/...` |

---

## `is_enabled` / `enable_*` Convention

- `count = var.is_enabled ? 1 : 0` on all optional resources
- Outputs return `null` / empty strings gracefully when disabled
- Optional components: NFS filesystems, VPS VM, Windows template, each k8s cluster add-ons

---

## Requires `null_resource` / `local-exec`

No native Terraform resource exists for these; use `local-exec` calling `cmk`:

| Resource | Reason |
|---|---|
| Template/ISO registration | No `cloudstack_template` create resource (only data source) |
| User-data registration (`registerUserData`) | No native resource |
| NFS SharedFileSystem (`createSharedFileSystem`) | No native resource |
| KVM host registration | No `cloudstack_host` resource |

Use content-hash `triggers` for idempotency.

---

## Import Strategy

All currently live resources use Terraform 1.5+ `import` blocks in `imports.tf` per module.
**Import order** (respects dependencies):
1. Zone → physical networks → pod → cluster → hosts → storage pools
2. Domain → account → resource limits
3. Offerings (disk, compute, network, VPC)
4. Templates / ISOs
5. VPC → networks → isolated network
6. SSH keypair

---

## Implementation Phases

### Phase 1 — Admin Foundation
- [ ] `catalog/modules/cloudstack-zone` — import zone, phys networks, pod, cluster, hosts, storage
- [ ] `catalog/modules/cloudstack-configuration` — ~30 global settings (admin scope)
- [ ] `catalog/modules/cloudstack-domain` — import domain + resource limits
- [ ] `catalog/modules/cloudstack-account` — import account, generate API key
- [ ] `catalog/modules/cloudstack-offerings` — import all offerings (for_each maps)
- [ ] `catalog/modules/cloudstack-templates` — register/import images (for_each, prevent_destroy)
- [ ] `catalog/stacks/cloudstack-admin` — composes above, `cloudstack.admin` provider
- [ ] `live/homecloud/cloudstack-admin` — first `plan` + import run

### Phase 2 — Domain Foundation
- [ ] `catalog/modules/cloudstack-vpc` — import VPC + network tiers
- [ ] `catalog/modules/cloudstack-network` — import iso-net-shared
- [ ] `catalog/modules/cloudstack-keypair` — import SSH keypair (domain-scoped)
- [ ] `catalog/modules/cloudstack-userdata` — register cloud-default + tailscale-router-debian
- [ ] `catalog/modules/cloudstack-shared-filesystem` — create/import NFS SharedFileSystems
- [ ] `catalog/stacks/cloudstack-homecloud` — composes above, `cloudstack.homecloud` provider
- [ ] `live/homecloud/cloudstack-homecloud` — `plan` + import run

### Phase 3 — Tailscale Router VM
- [ ] `catalog/modules/tailscale-key` — `tailscale_tailnet_key` for router VM
- [ ] `catalog/stacks/tailscale-vpn` — Ubuntu VM with cloud-init userdata
- [ ] `live/homecloud/tailscale-vpn` — `plan` + apply

### Phase 4 — Ops Cluster
- [ ] `catalog/modules/talos-config` — machine secrets + configs
- [ ] `catalog/modules/cloudstack-vm` — generic VM (Talos `user_data`, iso-net-shared)
- [ ] `catalog/modules/kubernetes-bootstrap` — Cilium + CCM + CSI + ArgoCD Helm releases
- [ ] `catalog/modules/onepassword-item` — write credentials to 1Password
- [ ] `catalog/stacks/talos-cluster` — full cluster: public IP + LB rule + VMs + bootstrap
- [ ] `catalog/stacks/argocd-setup` — ArgoCD + register both clusters
- [ ] `live/homecloud/ops-cluster` — `plan` + apply

### Phase 5 — Workload Cluster
- [ ] `live/homecloud/workload-cluster` — reuses `talos-cluster` stack; adds cert-manager
- [ ] ArgoCD App-of-Apps syncs `charts/` from main branch

### Phase 6 — Verification
- [ ] `terragrunt stack run plan` across all units — zero unintended replacements
- [ ] ArgoCD registers and syncs workload cluster
- [ ] Media server Helm chart deployed by ArgoCD (fix VPN credentials in stash first)

---

## State File Layout

```
infrastructure/.tfstate/
  homecloud/
    cloudstack-admin/terraform.tfstate
    cloudstack-homecloud/terraform.tfstate
    tailscale-vpn/terraform.tfstate
    ops-cluster/terraform.tfstate
    workload-cluster/terraform.tfstate
```

Local backend for now. Migration path: S3 backend with DynamoDB locking.

---

## Open Questions / Blockers

- **Talos image compression**: CloudStack may reject `.raw.gz`. If so, serve uncompressed `.raw`
  from a local web server or use CloudStack's built-in decompression (varies by version).
- **Public IP allocation**: `cloudstack_ipaddress` acquire semantics — confirm whether a specific
  IP from the public range (10.10.20.x) can be requested or must be auto-assigned.
- **NFS SharedFileSystem idempotency**: `null_resource` triggers based on config hash; verify
  `cmk listSharedFileSystems` can detect existing resources before creating.
- **ArgoCD cluster registration**: Requires ops cluster kubeconfig + workload cluster kubeconfig;
  both written to 1Password by the `onepassword-item` module before ArgoCD is bootstrapped.
