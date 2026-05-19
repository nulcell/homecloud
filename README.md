# HomeCloud

Self-hosted private cloud on bare metal. Talos + Cilium + ArgoCD + Longhorn + KubeVirt.

## Layout

| Path | Purpose |
| --- | --- |
| [`cluster/`](cluster/) | Talos machine configs + imperative bootstrap (Cilium, ArgoCD). Start at [`cluster/README.md`](cluster/README.md). |
| [`gitops/`](gitops/) | ArgoCD's source of truth — root, infrastructure, security, apps. |
| [`charts/`](charts/) | Helm umbrella charts referenced by `gitops/apps/*`. |
| [`manifests/`](manifests/) | Ad-hoc / one-shot manifests, applied manually. |
| [`scripts/`](scripts/) | Standalone operator utilities. |
| [`network/maas/`](network/maas/) | Legacy MaaS install — pending replacement with Pi-hole + netboot + Tailscale on a Pi. |

Conventions for agents and humans: [AGENTS.md](AGENTS.md).

## Setup

```bash
brew install mise op
mise install   # everything pinned in .mise.toml
```

`op` (1Password CLI) is the only required tool not managed by mise — it backs the `op://homecloud/...` URIs used in `.env` generation.

## Roadmap

- **Phase 1** — single-node Talos control plane (current).
- **Phase 2** — 3-node HA control plane. Skip 2-node (worse than 1-node for etcd quorum).
- **Phase 3** *(optional)* — dedicated workers.
- **Network refresh** — retire `network/maas/` in favor of a Raspberry Pi running Pi-hole (DNS + DHCP), netboot, and Tailscale.
