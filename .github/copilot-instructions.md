# HomeCloud Lab — Copilot Instructions

## Mandatory: Keep Docs in Sync

**After completing any task that modifies this repository, update both:**
- `.github/copilot-instructions.md` (this file)
- `AGENTS.md`

Reflect any changes to architecture, file structure, naming conventions, tooling, or workflows.

---

## Project Overview

This is a **home lab infrastructure-as-code repository** for a self-hosted private cloud built on bare metal. The stack layers from bottom to top:

1. **MaaS** (`maas/`) — bare-metal provisioning of physical servers
2. **Apache CloudStack** (`cloudstack/`) — IaaS layer running on KVM hypervisors (Ubuntu 24.04, CloudStack 4.20.1)
3. **Kubernetes** — CKS clusters managed via Cluster API (`cloudstack/compute/clusterapi/`) provisioned on CloudStack VMs
4. **Workloads** — Helm charts (`charts/`) deployed via ArgoCD with GitOps

**A Terragrunt migration is in progress** — see `infrastructure/PLAN.md` for the full plan. Tool versions are managed by `.mise.toml` at repo root; run `mise install` to set up the full toolchain.

## Infrastructure (`infrastructure/`)

Follows the **Gruntwork catalog + live pattern** (BrainIAC model):

- `catalog/modules/` — granular: smallest reusable Terraform modules, one resource type or tightly coupled set
- `catalog/stacks/` — baseline: full infrastructure components that compose granular modules
- `live/root.hcl` — Terragrunt root config: local state backend, provider version constraints only (no credentials)
- `live/homecloud/` — single live environment; units wire stacks together with explicit dependency graph via `dependency {}` blocks and `homecloud.stack.hcl`
- **`cloudstack-platform` is the only unit that uses the admin provider alias.** All other units use the homecloud domain user. Each catalog stack defines its own `providers.tf`.
- **Media server** is an ArgoCD Helm chart (`charts/media-server/`), not a Terraform VM. Its CloudStack NFS volumes (`enable_shared_storage`) are managed inside `cloudstack-platform`.
- All existing CloudStack resources are **imported** (not recreated) using `import {}` blocks.

## Architecture

- **Network**: CloudStack zone `zone-homecloud`, VPC network `homecloud-vpc_pub-net-1`, management gateway `10.10.31.254/20`, control plane endpoint `10.10.20.40:6443`
- **Networking (in-cluster)**: Cilium with kube-proxy replacement, cluster-pool IPAM (`10.128.0.0/16`), BPF masquerade
- **Ingress**: Traefik with Cloudflare DNS challenge for Let's Encrypt (`certIssuer: le`), cert resolver named `le`
- **DNS**: ExternalDNS backed by Cloudflare (`cloudflare-api-token` secret)
- **Storage**: CloudStack custom disk offering (`cloudstack-custom-disk-offering` StorageClass), NFS for CloudStack primary/secondary storage
- **Secrets**: 1Password CLI (`op://homecloud/...` URIs); `.env` files are generated with `op inject -i .env.example -o .env --force`
- **Domain**: `nulcell.com`

## Directory Structure

| Directory | Contents |
|---|---|
| `charts/` | Helm umbrella charts wrapping upstream charts (cilium, traefik, external-dns, monitoring) plus a custom n8n chart |
| `cloudstack/` | Setup scripts, cloud-init templates, Cluster API specs, CloudStack docs |
| `docker-compose/` | Docker Compose stacks (currently: *arr media server stack) — migrating to ArgoCD Helm chart (`charts/media-server/`); code in git stash pending VPN credential cleanup |
| `kubernetes/` | Ad-hoc Kubernetes manifests and testing resources |
| `maas/` | MaaS single-node install script |
| `infrastructure/` | Terragrunt live stacks + Terraform modules (`PLAN.md` is the source of truth) |
| `infrastructure.drawio` | Architecture diagram |

## Helm Charts (`charts/`)

Each chart in `charts/` follows the **umbrella pattern**: a `Chart.yaml` that depends on an upstream chart, a vendored `.tgz` in `charts/`, and a `values.yaml` that overrides upstream defaults.

Key conventions in `values.yaml` files:
- Ingress `className` is always `traefik`
- TLS cert issuer annotation is always `certIssuer: le`
- PVC `storageClass` is `cloudstack-custom-disk-offering`
- Container security context uses `runAsUser: 1000`, `runAsGroup: 1000`, `runAsNonRoot: true`
- Resources always specify both `requests` and `limits`

To update a vendored chart:
```bash
helm dependency update charts/<chart-name>/
```

To install/upgrade a chart:
```bash
helm upgrade --install <release-name> charts/<chart-name>/ -n <namespace> -f charts/<chart-name>/values.yaml
```

## CloudStack / Cluster API

- Kubernetes clusters are provisioned via **Cluster API with CloudStack provider** (`cluster.x-k8s.io/v1beta1`, `infrastructure.cluster.x-k8s.io/v1beta3`)
- Cluster spec is at `cloudstack/compute/clusterapi/homecloud-cks-cluster-spec.yaml`
- The CKS cluster uses Cilium as CNI (config at `cloudstack/compute/cni-config/cilium.yaml`)
- KVM hosts use Linux bridge networking (`cbr0`, `cbr1`, etc.)
- CloudStack management server setup: `cloudstack/setup/management-single-node.sh`

## Docker Compose (`docker-compose/media-server/`)

- Uses an `*arr` stack (Jellyfin, Jellyseerr, Gluetun VPN, etc.)
- All services run as `PUID=1000 / PGID=1000`
- Config stored at `$CONFIG_PATH`, media at `$DATA_PATH` (NFS mounts)
- Secrets use 1Password URIs in `.env.example`; generate `.env` with:
  ```bash
  op inject -i .env.example -o .env --force
  ```

## Key Tooling

Local workstation tools managed via Homebrew: `kubectl` (aliased `k`), `helm` (aliased `h`), `argocd`, `cilium-cli`, `clusterctl`, `tfenv`/`tgenv`, `cloudmonkey` (CloudStack CLI).

CloudMonkey (cmk) is the CLI for CloudStack — used for querying/managing CloudStack resources directly.
