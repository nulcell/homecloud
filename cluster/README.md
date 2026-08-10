# Cluster

Bring-up artifacts for the Talos Kubernetes cluster: machine configs and the imperative bootstrap of Cilium + ArgoCD. ArgoCD takes over from [`bootstrap/install.sh`](bootstrap/install.sh) onward - everything else lives at the repo root under [`/gitops/`](../gitops/), [`/charts/`](../charts/), and [`/manifests/`](../manifests/).

## Stack

- **OS**: [Talos Linux](https://www.talos.dev/)
- **CNI / LB / Gateway**: [Cilium](https://cilium.io/) - kube-proxy replacement, Gateway API, L2 announcements
- **Storage**: [Longhorn](https://longhorn.io/)
- **Virtualization**: [KubeVirt](https://kubevirt.io/)
- **GitOps**: [Argo CD](https://argo-cd.readthedocs.io/)
- **Certificates**: [cert-manager](https://cert-manager.io/) + Cloudflare DNS-01
- **Metrics**: metrics-server, kube-prometheus-stack
- **Secrets in Git**: SOPS + age

## Topology phases

- **Phase 1 (current)** - 1 control plane, scheduling on, Longhorn replica 1, etcd quorum 1.
- **Phase 2** - 3-node HA control plane. Jump straight from 1 → 3 (2-node etcd is worse than 1-node). Raise Longhorn default replicas to 3.
- **Phase 3** *(optional)* - dedicated workers.

## Bootstrap order

Imperative seed, then ArgoCD:

1. Build a custom Talos image at [Image Factory](https://factory.talos.dev/) with `iscsi-tools`, `util-linux-tools`, matching microcode, and optional `amdgpu`. Detail in [docs/bootstrap.md §1](docs/bootstrap.md#1-build-a-custom-talos-image).
2. Boot → generate config → patch → `talosctl apply-config` → `talosctl bootstrap`.
3. Apply Gateway API CRDs → install Cilium → install ArgoCD.
4. [`bootstrap/install.sh`](bootstrap/install.sh) finishes by applying [`/gitops/root/root-app.yaml`](../gitops/root/root-app.yaml). ArgoCD then reconciles everything under [`/gitops/infrastructure/`](../gitops/infrastructure/) and [`/gitops/apps/`](../gitops/apps/).

Cilium and ArgoCD stay on Helm - their values in [`bootstrap/`](bootstrap/) are the source of truth for those two. Everything else (cert-manager, Longhorn, metrics-server, KubeVirt, monitoring, gateways, workloads) is GitOps from day one.

## Key decisions

- Cilium replaces kube-proxy and provides Gateway API + L2 announcements. No MetalLB.
- Only Cilium and ArgoCD bootstrap imperatively; ArgoCD has no PV dependency so Longhorn comes up later via GitOps.
- SOPS + age for in-repo secrets (no External Secrets / Vault).
- System extensions baked into the Talos image at install time - adding them later needs an OS upgrade.

## Layout

```
cluster/
├── README.md
├── docs/
│   ├── bootstrap.md
│   └── argocd.md
├── talos/
│   ├── patches/        # machine-config patches
│   ├── generated/      # talosctl gen config output - gitignored
│   └── secrets/        # secrets bundle + talosconfig - gitignored
└── bootstrap/
    ├── install.sh      # idempotent helm-install; ends by applying the root Application
    ├── cilium-values.yaml
    ├── cilium-l2.yaml
    └── argocd-values.yaml
```

## Docs

- [bootstrap.md](docs/bootstrap.md) - step-by-step from a blank node to a working cluster.
- [argocd.md](docs/argocd.md) - app-of-apps layout, SOPS wiring, operating notes.
- [talos/README.md](talos/README.md) - common `talosctl` commands.

## Not here yet

- Backup strategy for etcd and Longhorn (add before this cluster holds anything irreplaceable).
- Non-privileged GPU device plugin (Jellyfin currently reaches `/dev/dri` via `privileged: true` as a stopgap - see [`/gitops/apps/media-stack/values.yaml`](../gitops/apps/media-stack/values.yaml)).
