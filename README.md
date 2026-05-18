# HomeCloud

Self-hosted private cloud on bare metal. A long-running platform for personal workloads and VMs — not a throwaway lab.

## What's here

| Path                                                       | Purpose                                                                                                                            |
| ---------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------- |
| [`kubernetes-infrastructure/`](kubernetes-infrastructure/) | The Talos + Cilium + ArgoCD + Longhorn + KubeVirt cluster. **Start here** — see its [README](kubernetes-infrastructure/README.md). |
| [`maas/`](maas/)                                           | Bare-metal provisioning via Canonical MaaS. Slated for replacement (see [Roadmap](#roadmap)).                                      |
| [`scripts/`](scripts/)                                     | Standalone operator utilities (media transcode, Rancher cleanup).                                                                  |
| [`infrastructure.drawio`](infrastructure.drawio)           | Architecture diagram (currently stale — pending redraw).                                                                           |
| [`.mise.toml`](.mise.toml)                                 | Pinned versions of all local CLIs used here. Run `mise install` to set up.                                                         |
| [`.sops.yaml`](.sops.yaml)                                 | SOPS encryption policy for secrets stored in-repo.                                                                                 |

## Stack at a glance

- **OS**: [Talos Linux](https://www.talos.dev/) — immutable, API-managed.
- **CNI / LB / Gateway**: [Cilium](https://cilium.io/) (kube-proxy replacement, Gateway API, L2 announcements). No MetalLB.
- **Storage**: [Longhorn](https://longhorn.io/) for replicated block storage.
- **Virtualization**: [KubeVirt](https://kubevirt.io/) for VMs as Kubernetes resources.
- **GitOps**: [Argo CD](https://argo-cd.readthedocs.io/) reading directly from this repo.
- **Certs**: [cert-manager](https://cert-manager.io/) with Cloudflare DNS-01.
- **Secrets in Git**: [SOPS](https://github.com/getsops/sops) + [age](https://github.com/FiloSottile/age).
- **Remote access**: Tailscale.

Full bootstrap flow, conventions, and topology phases live in [kubernetes-infrastructure/README.md](kubernetes-infrastructure/README.md).

## Local setup

```bash
# macOS — assumes Homebrew is installed
brew install mise op
mise install            # installs everything pinned in .mise.toml
```

The 1Password CLI (`op`) is the only required tool that isn't managed by mise — it backs the `op://homecloud/...` URIs used in `.env` generation.

## Roadmap

- **Phase 1** — single-node Talos control plane (current). Workloads scheduled on the control plane; Longhorn at replica 1.
- **Phase 2** — 3-node HA control plane. Skip the 2-node intermediate state (worse than 1-node for etcd quorum).
- **Phase 3** *(optional)* — dedicated worker nodes.
- **MaaS replacement** — Canonical MaaS is heavyweight for a single rack. Plan is to retire `maas/` in favor of a Raspberry Pi running Pi-hole (DNS + DHCP), netboot for PXE, and Tailscale for remote access.

## Repository conventions

- Don't run `kubectl apply` from the repo — manifests are reconciled by ArgoCD. For validation, use `helm template` / `helm lint` / `kubectl diff`.
- New workloads belong as Helm charts under [`kubernetes-infrastructure/charts/`](kubernetes-infrastructure/charts/) and ApplicationSet entries under [`kubernetes-infrastructure/gitops/apps/`](kubernetes-infrastructure/gitops/apps/).
- See [AGENTS.md](AGENTS.md) for the full set of conventions agents (and humans) should follow.
