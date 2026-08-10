# HomeCloud — Agent Instructions

Keep this file accurate. If a task changes architecture, structure, naming, tooling, or workflow, update AGENTS.md in the same change.

## Commandments

Non-negotiable, for every file in this repo:

1. Minimal code — the smallest change that does the job.
2. Simplicity over complexity — no speculative abstraction, options, or config.
3. Comments only when necessary, and concise — state constraints, not mechanics.
4. Low verbosity everywhere: code, config, docs, and agent output.

## Stack

Self-hosted private cloud on bare metal. Single-node today, designed to scale to a 3-node HA control plane.

- **OS**: Talos Linux. Machine-config patches in [`cluster/talos/patches/`](cluster/talos/patches/); image schematic baked at Talos Image Factory with `iscsi-tools`, `util-linux-tools`, microcode, optional `amdgpu`.
- **Cluster**: Kubernetes via Talos. Cilium + ArgoCD bootstrapped imperatively ([`cluster/bootstrap/install.sh`](cluster/bootstrap/install.sh)); everything else via GitOps.
- **CNI / LB / Gateway**: Cilium (kube-proxy replacement, Gateway API, L2 announcements). No MetalLB.
- **Storage**: Longhorn (replicated block).
- **Virtualization**: KubeVirt (VMs as Kubernetes resources).
- **GitOps**: ArgoCD reads this repo. Five ApplicationSets fan out one Application per directory under [`gitops/infrastructure/*`](gitops/infrastructure/) (wave `0`), [`gitops/operators/*`](gitops/operators/) (wave `5`), [`gitops/security/*`](gitops/security/) (wave `10`), [`gitops/services/*`](gitops/services/) (wave `15`), and [`gitops/apps/*`](gitops/apps/) (wave `100`).
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
| [`gitops/root/`](gitops/root/) | Root Application + five ApplicationSets (`infrastructure`, `operators`, `security`, `services`, `apps`) ordered by sync wave. |
| [`gitops/infrastructure/`](gitops/infrastructure/) | Base platform — every other layer can assume these are up: cert-manager, external-dns, external-secrets, gateway, headlamp, infra-app-httproutes, kube-prometheus-stack, loki, longhorn, metrics-server, registry-credentials. |
| [`gitops/operators/`](gitops/operators/) | Operators installing CRDs the upper layers consume: cnpg, falco, kubevirt, mariadb, tailscale. |
| [`gitops/security/`](gitops/security/) | Security stack — falco (runtime detection via falco-operator CRs + falco-talon response actions). |
| [`gitops/services/`](gitops/services/) | Platform services on top of operators: kubevirt. |
| [`gitops/apps/`](gitops/apps/) | Workloads (`actual-budget`, `authentik`, `cloudflared`, `mealie`, `media-stack`, `n8n`, `portfolio`, `uptime-kuma`). |
| [`gitops/exprimental/`](gitops/exprimental/) | Staging area, not referenced by any ApplicationSet — candidates for promotion or retirement. |
| [`charts/`](charts/) | Helm umbrella charts referenced via `chartHome: ../../../charts` from `gitops/apps/*`. |
| [`manifests/`](manifests/) | Ad-hoc / one-shot manifests applied manually — NOT reconciled by ArgoCD. |
| [`scripts/`](scripts/) | Standalone operator utilities. |
| [`network/netboot/`](network/netboot/) | Notes for the planned Pi-hole + netboot + Tailscale provisioning host. |
| [`.mise.toml`](.mise.toml) | Pinned local CLIs (`mise install`). |
| [`.sops.yaml`](.sops.yaml) | SOPS encryption policy. |

## Conventions

- **Never `kubectl apply` from this repo.** ArgoCD owns reconciliation for everything under `gitops/`. Validate with `helm template`, `helm lint`, or `kubectl diff -f`. The user applies anything manual themselves.
- **New workloads**: umbrella Helm chart under [`charts/<name>/`](charts/) (chart depends on upstream, vendored `.tgz`, `values.yaml` overrides), then a directory under [`gitops/apps/<name>/`](gitops/apps/) with a `kustomization.yaml` referencing the chart via `helmGlobals.chartHome: ../../../charts`. The `apps` ApplicationSet picks it up on the next reconcile.
- **Ad-hoc / one-shot manifests** go in [`manifests/`](manifests/) and are applied manually.
- **Helm chart values**: prefer Gateway API `HTTPRoute` over Ingress; `storageClassName: longhorn`; security context `runAsNonRoot: true` with explicit `runAsUser`/`runAsGroup`; always set both `resources.requests` and `resources.limits`.
- **Publishing an app to the internet**: apps never bind a public hostname directly. Give the `HTTPRoute` an origin hostname on the `internal` Gateway's `https-internal` listener (`<app>.internal.nulcell.com`, covered by the wildcard cert), then add the public hostname to `ingress` in [`gitops/apps/cloudflared/values.yaml`](gitops/apps/cloudflared/values.yaml) with `originRequest.httpHostHeader` set to that origin hostname. Cloudflare terminates public TLS; the PostSync job in that chart registers the tunnel DNS record for every `hostname` in the list.
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
- **Bare-metal provisioning**: in planning — Pi-hole (DNS + DHCP) + netboot + Tailscale on a Raspberry Pi. The old MaaS install script is gone; see [`network/netboot/`](network/netboot/).
- **Renovate**: planned for chart and tool versions; new charts should pin upstream versions Renovate can track.
