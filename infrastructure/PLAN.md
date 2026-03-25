# Infrastructure Terragrunt Plan

## Overview

Convert the entire `cloudstack/docs/00-CLI.md` CloudMonkey command set into a fully
deterministic Terragrunt + Terraform stack under `infrastructure/`. The only manual
prerequisite is a running CloudStack management server with admin credentials in
1Password (`op://homecloud/CloudStack - admin/...`).

**Scope excludes:** CloudStack zone/physical network/host setup (already live —
these are imported, not recreated), and the Kubernetes section of the CLI (replaced
entirely by the Talos + Tailscale approach below).

---

## Provider Stack

| Provider | Source | Purpose |
|---|---|---|
| CloudStack | `apache/cloudstack` | All CloudStack resources |
| Tailscale | `tailscale/tailscale` | Auth keys, ACLs, tailnet settings |
| 1Password | `1Password/onepassword` | Read existing secrets; write generated ones |
| Talos | `siderolabs/talos` | Machine config generation, cluster bootstrap |
| Helm | `hashicorp/helm` | Bootstrap Cilium, CCM, CSI, ArgoCD |
| Kubernetes | `hashicorp/kubernetes` | Namespaces, secrets, post-bootstrap resources |
| Local | `hashicorp/local` | Write kubeconfig / talosconfig files locally |

> **Two CloudStack provider aliases are required:**
> - `cloudstack.admin` — admin API key/secret (reads from `op://homecloud/CloudStack - admin/...`)
> - `cloudstack.homecloud` — homecloud-admin API key/secret (reads from `op://homecloud/CloudStack - homecloud-admin/...`)

---

## Directory Structure

Follows the **Gruntwork catalog + live pattern** (BrainIAC model):
- `catalog/modules/` — granular: smallest, single-concern reusable Terraform modules
- `catalog/stacks/` — baseline: compose granular modules into full infrastructure components
- `live/` — single Terragrunt live environment; units wire stacks together with explicit dependencies

```
infrastructure/
  PLAN.md                          ← this file

  catalog/
    modules/                       ← granular: smallest reusable Terraform modules
      cloudstack-configuration/    ← global settings (~30 update configuration cmds)
      cloudstack-zone/             ← zone, physical networks, pod, cluster, hosts, storage
      cloudstack-domain/           ← domain + resource limits
      cloudstack-account/          ← account creation
      cloudstack-offerings/        ← disk, compute, network, vpc offerings
      cloudstack-templates/        ← OS templates, Talos ISO, Windows ISOs
      cloudstack-vpc/              ← VPC + pub/priv subnets + ACLs
      cloudstack-network/          ← isolated networks
      cloudstack-keypair/          ← SSH keypair (reads pub key from 1Password)
      cloudstack-userdata/         ← user data script registration
      cloudstack-vm/               ← generic VM (is_enabled, optional Tailscale)
      cloudstack-shared-filesystem/← NFS shared filesystems (is_enabled)
      tailscale-key/               ← tailnet_key (ephemeral, tagged, reusable)
      talos-config/                ← machine secrets, control-plane + worker configs
      kubernetes-bootstrap/        ← Helm: Cilium, CCM, CSI, external-dns
      onepassword-item/            ← write generated credentials to 1Password

    stacks/                        ← baseline: full infrastructure components
      cloudstack-platform/         ← complete admin CloudStack setup
      tailscale-vpn/               ← Tailscale router VM on CloudStack (is_enabled)
      talos-cluster/               ← full Talos k8s cluster (parameterised, is_enabled)
      argocd-setup/                ← ArgoCD + App-of-Apps bootstrap (is_enabled)
      media-server/                ← shared filesystems + media VM (is_enabled)

  live/                            ← Terragrunt live repository (single environment)
    root.hcl                       ← root: local state, provider versions, common inputs
    homecloud/
      account.hcl                  ← environment-level variables (URLs, CIDRs, vault refs)
      homecloud.stack.hcl          ← explicit stack: all units + dependency graph
      cloudstack-platform/
        terragrunt.hcl
      tailscale-vpn/
        terragrunt.hcl
      ops-cluster/
        terragrunt.hcl             ← talos-cluster + argocd-setup for ops workloads
      workload-cluster/
        terragrunt.hcl             ← talos-cluster for user workloads
      media-server/
        terragrunt.hcl             ← media-server (is_enabled toggle)
```

---

## Kubernetes Architecture

### No CKS / No Cluster API

Kubernetes clusters are **plain Talos Linux VMs on CloudStack**, connected via
**Tailscale**. Each node joins the Tailscale tailnet using a dedicated ephemeral
auth key injected as a Talos machine config extension.

### Talos + Tailscale Node Topology

```
CloudStack VPC (10.0.0.0/24)
  pub-net-1  (10.0.0.0/26)   ← control plane nodes + Tailscale (MagicDNS reachable)
  priv-net-1 (10.0.0.64/26)  ← worker nodes
  priv-net-2 (10.0.0.128/26) ← worker nodes (expansion)

Each Talos VM:
  - Boots from Talos ISO registered in CloudStack
  - Machine config delivered via CloudStack user-data / config drive
  - Tailscale system extension enabled in machine config
  - Node joins tailnet as tagged device (tag:k8s-<cluster-name>)
  - Inter-node communication uses VPC subnet IPs (not Tailscale IPs)
  - Tailscale provides: external access to kube-apiserver, MagicDNS names
```

### Talos ISO Strategy

The Talos ISO must be built with the **Tailscale system extension** included using
the [Talos Image Factory](https://factory.talos.dev). Provide the artifact URL to the
`cloudstack-templates` module.

**Required extensions:**
- `siderolabs/tailscale` — Tailscale daemon as a Talos system extension

### Two Clusters

| Cluster | Name | Networks | Workloads |
|---|---|---|---|
| Ops | `homecloud-ops` | pub-net-1 (CP), priv-net-1 (workers) | ArgoCD, Prometheus+Grafana, Traefik (ops), n8n |
| Workload | `homecloud-workload` | pub-net-1 (CP), priv-net-1/2 (workers) | Media server, user apps, all ArgoCD-deployed charts |

The **ops cluster** bootstraps ArgoCD which then manages the workload cluster and
all application-layer Helm charts via GitOps (pointing at `charts/` in this repo).

### Helm Charts Bootstrapped by Terraform (both clusters)

These must exist before ArgoCD can function:
1. **Cilium** — CNI (kube-proxy replacement, cluster-pool IPAM)
2. **CloudStack Cloud Controller Manager (CCM)** — node lifecycle, LoadBalancer
3. **CloudStack CSI Driver** — dynamic PV provisioning (`cloudstack-custom-disk-offering`)

Additionally on the **workload cluster only**:
4. **External-DNS** — Cloudflare DNS sync

Additionally on the **ops cluster only**:
5. **ArgoCD** — then takes over all application charts

---

## CloudStack Provider Resource Coverage

### Native Terraform Resources (no workaround needed)

| CLI Command Group | Terraform Resource |
|---|---|
| Global settings | `cloudstack_configuration` |
| Zone | `cloudstack_zone` (via zone-wizard resources) |
| Physical network | `cloudstack_physical_network` |
| Traffic type | `cloudstack_traffic_type` |
| Network service provider | `cloudstack_network_service_provider_state` |
| Pod | `cloudstack_pod` |
| Hypervisor cluster | `cloudstack_cluster` |
| Primary storage | `cloudstack_storage_pool` |
| Secondary storage | `cloudstack_secondary_storage` |
| Domain | `cloudstack_domain` |
| Account | `cloudstack_account` |
| Resource limits | `cloudstack_limits` |
| Disk offering | `cloudstack_disk_offering` |
| Service offering | `cloudstack_service_offering` |
| Network offering | `cloudstack_network_offering` |
| VPC offering | `cloudstack_vpc_offering` |
| VPC | `cloudstack_vpc` |
| Network (VPC tier / isolated) | `cloudstack_network` |
| Network ACL | `cloudstack_network_acl` + `cloudstack_network_acl_rule` |
| VM instance | `cloudstack_instance` |
| SSH keypair | `cloudstack_ssh_keypair` |
| Role | `cloudstack_role` |

### Requires `null_resource` / `local-exec` (cloudmonkey wrapper)

| CLI Command Group | Reason |
|---|---|
| KVM host registration (`add host`) | No `cloudstack_host` resource in provider |
| Template registration (`register template`) | No native resource; provider has data source only |
| ISO registration (`register iso`) | No native resource |
| User data registration (`registerUserData`) | No native resource |
| CNI configuration (`registerCniConfiguration`) | No native resource |
| Shared filesystem (`createSharedFileSystem`) | No native resource |
| Talos ISO Kubernetes version (`addKubernetesSupportedVersion`) | Not needed — we use raw Talos VMs, not CKS |

For `null_resource` wraps: use `local-exec` calling `cmk -p admin` commands, with
`triggers` based on content hashes to make them idempotent.

---

## Secrets Strategy

### Reading from 1Password (existing secrets)

| Secret | 1Password Path | Used In |
|---|---|---|
| CloudStack admin API key | `op://homecloud/CloudStack - admin/api_key` | `cloudstack.admin` provider |
| CloudStack admin secret | `op://homecloud/CloudStack - admin/secret_key` | `cloudstack.admin` provider |
| homecloud-admin username | `op://homecloud/CloudStack - homecloud-admin/username` | `cloudstack_account` |
| homecloud-admin password | `op://homecloud/CloudStack - homecloud-admin/password` | `cloudstack_account` |
| homecloud-admin email | `op://homecloud/CloudStack - homecloud-admin/details/Email` | `cloudstack_account` |
| SSH public key | `op://homecloud/nulcell/public key` | `cloudstack_ssh_keypair` |
| Tailscale auth key | `op://homecloud/Tailscale Token/credential` | `tailscale` provider token |

### Writing to 1Password (generated secrets)

| Secret | Written By | 1Password Item |
|---|---|---|
| Talos machine secrets | `onepassword-item` granular module | `op://homecloud/Talos - homecloud-ops/...` |
| ops cluster kubeconfig | `onepassword-item` granular module | `op://homecloud/Kubeconfig - homecloud-ops/...` |
| ops talosconfig | `onepassword-item` granular module | `op://homecloud/Talosconfig - homecloud-ops/...` |
| workload cluster kubeconfig | `onepassword-item` granular module | `op://homecloud/Kubeconfig - homecloud-workload/...` |
| workload talosconfig | `onepassword-item` granular module | `op://homecloud/Talosconfig - homecloud-workload/...` |
| homecloud-admin API key/secret | `onepassword-item` granular module | `op://homecloud/CloudStack - homecloud-admin/api_key` |

---

## `is_enabled` Flag Convention

All baseline modules and any granular module representing an optional component
expose an `is_enabled` variable (default `true`). When `false`:
- All resources in the module use `count = var.is_enabled ? 1 : 0`
- Outputs return `null` / empty strings gracefully
- Dependent live stacks check `is_enabled` before referencing outputs

**Optional components (default `is_enabled = false` until explicitly toggled):**
- `tailscale-vpn` baseline
- `media-server` baseline
- VPS VM in cloudstack-platform
- Windows Server template registration

---

## Terragrunt Live Root Config Pattern

```hcl
# infrastructure/live/root.hcl
locals {
  common_vars = {
    cloudstack_url  = "http://cloudstack.nulcell.com:8080/client/api"
    zone_name       = "zone-homecloud"
    domain_name     = "homecloud"
    account_name    = "homecloud"
    tailnet         = "nulcell.com"
  }
}

remote_state {
  backend = "local"
  config  = { path = "${get_repo_root()}/infrastructure/.tfstate/${path_relative_to_include()}/terraform.tfstate" }
  generate = {
    path      = "backend.tf"
    if_exists = "overwrite_terragrunt"
  }
}

generate "provider_versions" {
  path      = "provider_versions.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<-EOF
    terraform {
      required_providers {
        cloudstack  = { source = "apache/cloudstack" }
        tailscale   = { source = "tailscale/tailscale" }
        onepassword = { source = "1Password/onepassword" }
        talos       = { source = "siderolabs/talos" }
        helm        = { source = "hashicorp/helm" }
        kubernetes  = { source = "hashicorp/kubernetes" }
      }
    }
  EOF
}
```

---

## Import Strategy for Existing Resources

All currently live resources must be imported before any `terraform apply`. Each
granular module should include an `imports.tf` file with `import` blocks (Terraform
1.5+) referencing the known resource IDs/names.

**Import order (respects dependency graph):**
1. Zone → physical networks → pod → cluster → hosts → storage pools
2. Domain → account → resource limits
3. Offerings (disk, compute, network, VPC)
4. Templates / ISOs
5. VPC → networks
6. SSH keypair

---

## Implementation Phases

### Phase 1 — Foundation
- [ ] `live/root.hcl` root config (local state, provider versions)
- [ ] `live/homecloud/account.hcl` environment variables
- [ ] `catalog/modules/cloudstack-zone` — import existing zone resources
- [ ] `catalog/modules/cloudstack-configuration` — global settings
- [ ] `catalog/modules/cloudstack-domain` — import domain + limits
- [ ] `catalog/modules/cloudstack-account` — import homecloud account
- [ ] `catalog/modules/cloudstack-offerings` — import all offerings
- [ ] `catalog/modules/cloudstack-templates` — import existing templates + Talos ISO registration
- [ ] `catalog/modules/cloudstack-keypair` — import SSH keypair
- [ ] `catalog/modules/cloudstack-userdata` — register user data scripts
- [ ] `catalog/stacks/cloudstack-platform` — compose all of above
- [ ] `live/homecloud/cloudstack-platform` — first live apply + import run

### Phase 2 — Networking
- [ ] `catalog/modules/cloudstack-vpc` — import existing VPC + networks
- [ ] `catalog/modules/cloudstack-network` — import iso-net-shared
- [ ] `catalog/modules/tailscale-key` — Tailscale auth key generation
- [ ] `catalog/stacks/tailscale-vpn` — VPN router VM (is_enabled=false by default)
- [ ] `live/homecloud/tailscale-vpn`

### Phase 3 — Ops Kubernetes Cluster
- [ ] `catalog/modules/talos-config` — Talos machine secrets + configs + Tailscale extension
- [ ] `catalog/modules/cloudstack-vm` — generic VM module
- [ ] `catalog/modules/kubernetes-bootstrap` — Cilium + CCM + CSI Helm releases
- [ ] `catalog/modules/onepassword-item` — write cluster credentials to 1Password
- [ ] `catalog/stacks/talos-cluster` — full parameterised Talos cluster
- [ ] `catalog/stacks/argocd-setup` — ArgoCD + App-of-Apps
- [ ] `live/homecloud/ops-cluster`

### Phase 4 — Workload Kubernetes Cluster
- [ ] `live/homecloud/workload-cluster` (reuses `catalog/stacks/talos-cluster`)

### Phase 5 — Optional Workloads
- [ ] `catalog/modules/cloudstack-shared-filesystem` — NFS shared filesystems
- [ ] `catalog/stacks/media-server` — shared filesystems + media server VM (is_enabled)
- [ ] `live/homecloud/media-server`

---

## State File Layout

```
infrastructure/
  .tfstate/
    homecloud/
      cloudstack-platform/terraform.tfstate
      tailscale-vpn/terraform.tfstate
      ops-cluster/terraform.tfstate
      workload-cluster/terraform.tfstate
      media-server/terraform.tfstate
```

> `.tfstate/` is gitignored. Migration to S3 backend requires only updating
> `remote_state` in `live/terragrunt.hcl`.

---

## Notes & Open Items

- **Talos ISO URL**: To be provided. Use [Talos Image Factory](https://factory.talos.dev)
  with `siderolabs/tailscale` extension enabled. Register resulting ISO URL in
  `granular/cloudstack-templates`.
- **CloudStack CCM**: Use `cloudstack/cloudstack-cloud-controller-manager` Helm chart.
- **CloudStack CSI**: Use `cloudstack/cloudstack-csi` Helm chart.
- **Cilium version**: Stay aligned with `charts/cilium/` (currently v1.18.4).
- **Two CloudStack providers**: The provider supports `config`+`profile` pointing at
  the local cloudmonkey config file, which may simplify credential setup.
- **`null_resource` cloudmonkey commands**: Wrap in a reusable `local-exec` pattern
  with `triggers = { hash = sha256(content) }` for idempotency.
- **ArgoCD App-of-Apps**: Points at `charts/` directory in this repo on the `main`
  branch. Workload cluster apps deployed via ArgoCD `ApplicationSet`.
