# HomeCloud — Agent Instructions

Keep this file accurate. If a task changes architecture, structure, naming, tooling, or workflow, update AGENTS.md in the same change.

## Stack

Self-hosted private cloud on bare metal. Single-node today, designed to scale to a 3-node HA control plane.

- **OS**: Talos Linux. Machine-config patches in [`cluster/talos/patches/`](cluster/talos/patches/); image schematic baked at Talos Image Factory with `iscsi-tools`, `util-linux-tools`, microcode, optional `amdgpu`.
- **Cluster**: Kubernetes via Talos. Cilium + ArgoCD bootstrapped imperatively ([`cluster/bootstrap/install.sh`](cluster/bootstrap/install.sh)); everything else via GitOps.
- **CNI / LB / Gateway**: Cilium (kube-proxy replacement, Gateway API, L2 announcements). No MetalLB.
- **Storage**: Longhorn (replicated block).
- **Virtualization**: KubeVirt (VMs as Kubernetes resources).
- **GitOps**: ArgoCD reads this repo. Two ApplicationSets fan out one Application per directory under [`gitops/infrastructure/*`](gitops/infrastructure/) and [`gitops/apps/*`](gitops/apps/).
- **Certs**: cert-manager + Cloudflare DNS-01.
- **Secrets in Git**: SOPS + age (`.enc.yaml` files; policy in [`.sops.yaml`](.sops.yaml)). 1Password CLI (`op://homecloud/...`) for runtime injection.
- **Remote access**: Tailscale.
- **Domain**: `nulcell.com`.

Deep reference: [`cluster/README.md`](cluster/README.md). Bootstrap steps: [`cluster/docs/bootstrap.md`](cluster/docs/bootstrap.md). ArgoCD layout + SOPS wiring: [`cluster/docs/argocd.md`](cluster/docs/argocd.md). Talos commands: [`cluster/talos/README.md`](cluster/talos/README.md).

## Directory map

| Path | Contents |
| --- | --- |
| [`cluster/bootstrap/`](cluster/bootstrap/) | `install.sh` + values for Cilium, Cilium L2, ArgoCD. |
| [`cluster/talos/`](cluster/talos/) | Machine-config patches. `generated/` and `secrets/` are gitignored. |
| [`cluster/docs/`](cluster/docs/) | `bootstrap.md`, `argocd.md`. |
| [`gitops/root/`](gitops/root/) | Root Application + ApplicationSets. |
| [`gitops/infrastructure/`](gitops/infrastructure/) | Platform: cert-manager, longhorn, metrics-server, cnpg, kube-prometheus-stack, kubevirt, gateway, external-dns, infra-app-httproutes, sops-secrets. |
| [`gitops/apps/`](gitops/apps/) | Workloads (`media-stack`, `n8n`). |
| [`gitops/deprecated/`](gitops/deprecated/) | Retired manifests — never reference from an active ApplicationSet. |
| [`charts/`](charts/) | Helm umbrella charts referenced via `chartHome: ../../../charts` from `gitops/apps/*`. |
| [`manifests/`](manifests/) | Ad-hoc / one-shot manifests applied manually — NOT reconciled by ArgoCD. |
| [`scripts/`](scripts/) | Standalone operator utilities. |
| [`network/maas/`](network/maas/) | Legacy MaaS install. Slated for Pi-hole + netboot + Tailscale on a Pi. Don't expand. |
| [`.mise.toml`](.mise.toml) | Pinned local CLIs (`mise install`). |
| [`.sops.yaml`](.sops.yaml) | SOPS encryption policy. |

## Conventions

- **Never `kubectl apply` from this repo.** ArgoCD owns reconciliation for everything under `gitops/`. Validate with `helm template`, `helm lint`, or `kubectl diff -f`. The user applies anything manual themselves.
- **New workloads**: umbrella Helm chart under [`charts/<name>/`](charts/) (chart depends on upstream, vendored `.tgz`, `values.yaml` overrides), then a directory under [`gitops/apps/<name>/`](gitops/apps/) with a `kustomization.yaml` referencing the chart via `helmGlobals.chartHome: ../../../charts`. The `apps` ApplicationSet picks it up on the next reconcile.
- **Ad-hoc / one-shot manifests** go in [`manifests/`](manifests/) and are applied manually.
- **Helm chart values**: prefer Gateway API `HTTPRoute` over Ingress; `storageClassName: longhorn`; security context `runAsNonRoot: true` with explicit `runAsUser`/`runAsGroup`; always set both `resources.requests` and `resources.limits`.
- **Talos changes** go through [`cluster/talos/patches/`](cluster/talos/patches/) — never edit `generated/` directly. System extensions (iscsi-tools, util-linux-tools, microcode, amdgpu) bake into the image at install time; adding them later needs an OS upgrade — flag this on any change.
- **Secrets**: `.enc.yaml` files only (per `.sops.yaml`'s `path_regex`); `.env` files generated locally from `.env.example` via `op inject` and gitignored; never commit a `.env` or raw token.
- **Shell scripts** target Ubuntu 24.04 LTS unless otherwise noted; idempotent where possible.

## Common commands

```bash
# Vendor / refresh chart dependencies
helm dependency update charts/<chart>/

# Validate without applying
helm template <release> charts/<chart>/ -f gitops/apps/<chart>/values.yaml
helm lint charts/<chart>/
```

Talos workflow lives in [`cluster/talos/README.md`](cluster/talos/README.md).

## Roadmap notes

- **HA**: 1 → 3 control planes directly; two-node etcd is worse than single-node.
- **MaaS replacement**: in planning — Pi-hole (DNS + DHCP) + netboot + Tailscale on a Raspberry Pi. Don't deepen the investment in `network/maas/`.
- **Renovate**: planned for chart and tool versions; new charts should pin upstream versions Renovate can track.
