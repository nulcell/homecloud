# HomeCloud — Agent Instructions

Keep this file accurate. If a task changes the architecture, structure, naming, tooling, or workflow, update AGENTS.md in the same change.

---

## What this repo is

A self-hosted private cloud running on bare metal. Single-node today, designed to scale to a 3-node HA control plane.

- **OS**: Talos Linux (immutable, API-managed).
- **Cluster**: Kubernetes via Talos, bootstrapped imperatively for Cilium + ArgoCD only.
- **CNI / LB / Gateway**: Cilium with kube-proxy replacement, Gateway API, L2 announcements. No MetalLB.
- **Storage**: Longhorn (replicated block).
- **Virtualization**: KubeVirt (VMs as Kubernetes resources).
- **GitOps**: ArgoCD reads this repo. App-of-apps + ApplicationSets.
- **Certs**: cert-manager with Cloudflare DNS-01 (`ClusterIssuer` per environment).
- **Secrets in Git**: SOPS + age. 1Password CLI (`op://homecloud/...`) for things that need injection at runtime.
- **Remote access**: Tailscale.
- **Domain**: `nulcell.com`.

The deep reference is [kubernetes-infrastructure/README.md](kubernetes-infrastructure/README.md). The Talos-specific commands live in [kubernetes-infrastructure/talos/README.md](kubernetes-infrastructure/talos/README.md). The bootstrap and ArgoCD docs are in [kubernetes-infrastructure/docs/](kubernetes-infrastructure/docs/).

---

## Directory map

| Path                                                                                                   | Contents                                                                                                                                                       |
| ------------------------------------------------------------------------------------------------------ | -------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| [`kubernetes-infrastructure/bootstrap/`](kubernetes-infrastructure/bootstrap/)                         | Imperative seed: `install.sh`, `cilium-values.yaml`, `cilium-l2.yaml`, `argocd-values.yaml`.                                                                   |
| [`kubernetes-infrastructure/talos/`](kubernetes-infrastructure/talos/)                                 | Talos machine-config patches; `generated/` and `secrets/` are gitignored.                                                                                      |
| [`kubernetes-infrastructure/gitops/root/`](kubernetes-infrastructure/gitops/root/)                     | The root `Application` and `ApplicationSet`s ArgoCD reconciles first.                                                                                          |
| [`kubernetes-infrastructure/gitops/infrastructure/`](kubernetes-infrastructure/gitops/infrastructure/) | Platform components: cert-manager, Longhorn, KubeVirt, metrics-server, kube-prometheus-stack, external-dns, gateway, sops-secrets, cnpg, infra-app-httproutes. |
| [`kubernetes-infrastructure/gitops/apps/`](kubernetes-infrastructure/gitops/apps/)                     | User workloads (currently `media-stack`, `n8n`).                                                                                                               |
| [`kubernetes-infrastructure/gitops/deprecated/`](kubernetes-infrastructure/gitops/deprecated/)         | Holding area for retired manifests — do not reference from active ApplicationSets.                                                                             |
| [`kubernetes-infrastructure/charts/`](kubernetes-infrastructure/charts/)                               | Helm umbrella charts (`media-stack`, `n8n`).                                                                                                                   |
| [`kubernetes-infrastructure/other/`](kubernetes-infrastructure/other/)                                 | Ad-hoc / one-shot manifests: VM templates, VPS, transcode-media job, loader SSH.                                                                               |
| [`kubernetes-infrastructure/docs/`](kubernetes-infrastructure/docs/)                                   | `bootstrap.md`, `argocd.md`.                                                                                                                                   |
| [`maas/`](maas/)                                                                                       | Canonical MaaS single-node script. Slated for replacement with Pi-hole + netboot + Tailscale on a Raspberry Pi. Avoid expanding it.                            |
| [`scripts/`](scripts/)                                                                                 | Standalone operator utilities (`media/transcode-media.sh`, `rancher/cleanup-rancher.sh`).                                                                      |
| [`.mise.toml`](.mise.toml)                                                                             | Pinned local CLIs. `mise install` sets up the full toolchain.                                                                                                  |
| [`.sops.yaml`](.sops.yaml)                                                                             | SOPS encryption policy.                                                                                                                                        |
| `infrastructure.drawio`                                                                                | Architecture diagram — currently stale.                                                                                                                        |

---

## Conventions

### Workload changes

- Production workloads belong as Helm charts under `kubernetes-infrastructure/charts/<name>/` following the **umbrella pattern**: `Chart.yaml` declaring the upstream chart as a dependency, vendored `.tgz` under `charts/`, and a `values.yaml` with overrides.
- Wire a new chart in by adding it to the relevant ApplicationSet under `kubernetes-infrastructure/gitops/apps/` or `gitops/infrastructure/`.
- Ad-hoc / one-shot manifests go in `kubernetes-infrastructure/other/` and are *not* picked up by ArgoCD — they're applied manually.

### Do not `kubectl apply` from the repo

ArgoCD owns reconciliation for everything under `gitops/`. To validate changes, use `helm template`, `helm lint`, or `kubectl diff -f` — not `apply`. The user runs apply themselves when needed.

### Helm chart values

- Ingress / routing: prefer Gateway API `HTTPRoute` over Ingress where possible (Cilium is the Gateway provider).
- TLS: cert-manager `ClusterIssuer` with Cloudflare DNS-01.
- Persistence: `storageClassName: longhorn` (Longhorn is the default storage class).
- Container security context: `runAsNonRoot: true`, explicit `runAsUser` / `runAsGroup`.
- Always set both `resources.requests` and `resources.limits`.

### Secrets

- In-cluster manifests use SOPS + age (`.sops.yaml` defines the policy).
- Local `.env` files are generated from `.env.example` via `op inject -i .env.example -o .env --force` and are gitignored.
- Never commit a `.env`, a decrypted secret, or a raw token.

### Talos changes

- Machine-config changes go through `kubernetes-infrastructure/talos/patches/` — never edit `generated/` directly.
- System extensions (Longhorn's `iscsi-tools`, `util-linux-tools`; microcode; AMD GPU firmware) are baked into the Talos image at install time. Adding extensions later requires an OS upgrade — note this when proposing changes.

### Bootstrap order

Imperative for Cilium + ArgoCD only. Everything else (cert-manager, Longhorn, KubeVirt, metrics-server, monitoring, ...) comes up via GitOps once `bootstrap/install.sh` applies the root `Application`. See [kubernetes-infrastructure/docs/bootstrap.md](kubernetes-infrastructure/docs/bootstrap.md).

### Shell scripts

- Target Ubuntu 24.04 LTS unless otherwise noted.
- Idempotent where possible.

---

## Common commands

```bash
# Vendor / refresh a chart's dependencies
helm dependency update kubernetes-infrastructure/charts/<chart>/

# Validate a chart without applying
helm template <release> kubernetes-infrastructure/charts/<chart>/ \
  -f kubernetes-infrastructure/charts/<chart>/values.yaml
helm lint kubernetes-infrastructure/charts/<chart>/

# Talos config workflow lives in kubernetes-infrastructure/talos/README.md.
```

---

## Roadmap notes for agents

- **HA**: jump from 1 → 3 control planes, never via 2. Two-node etcd is *worse* than single-node.
- **MaaS replacement**: in planning. Future bare-metal provisioning will be Pi-hole (DNS + DHCP) + netboot + Tailscale on a Raspberry Pi. Don't deepen the investment in `maas/`.
- **Renovate**: planned for managing tool and chart versions. New charts should use upstream versions that Renovate can track.
