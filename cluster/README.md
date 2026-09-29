# Cluster

Bring-up artifacts for the Talos Kubernetes cluster: machine configs and the imperative bootstrap of Cilium + ArgoCD. ArgoCD takes over from [`bootstrap/helmfile.yaml`](bootstrap/helmfile.yaml) onward - everything else lives at the repo root under [`/gitops/`](../gitops/) and [`/manifests/`](../manifests/).

## Stack

- **OS**: [Talos Linux](https://www.talos.dev/) v1.13.2, Kubernetes v1.36.1
- **CNI / LB / Gateway**: [Cilium](https://cilium.io/) 1.20.0 - kube-proxy replacement, Gateway API v1.6.1, L2 announcements
- **Storage**: [Longhorn](https://longhorn.io/)
- **Virtualization**: [KubeVirt](https://kubevirt.io/) + CDI
- **GitOps**: [Argo CD](https://argo-cd.readthedocs.io/) 10.3.0
- **Certificates**: [cert-manager](https://cert-manager.io/) + Cloudflare DNS-01
- **Metrics / logs**: metrics-server, kube-prometheus-stack, Loki + Alloy
- **Secrets**: [External Secrets](https://external-secrets.io/) against 1Password

## Topology phases

- **Phase 1 (current)** - 1 control plane with `allowSchedulingOnControlPlanes: true`, 1 worker, Longhorn replica 2, etcd quorum 1.
- **Phase 2** - 3-node HA control plane. Jump straight from 1 → 3 (2-node etcd is worse than 1-node). Raise Longhorn default replicas to 3.
- **Phase 3** *(optional)* - dedicated workers; flip `allowSchedulingOnControlPlanes` to false.

## Bootstrap order

Imperative seed, then ArgoCD:

1. Build a custom Talos image at [Image Factory](https://factory.talos.dev/) with `iscsi-tools`, `util-linux-tools`, matching microcode, and optional `amdgpu`. Detail in [docs/bootstrap.md §1](docs/bootstrap.md#1-build-a-custom-talos-image).
2. Boot → generate config → patch → `talosctl apply-config` → `talosctl bootstrap`.
3. Apply Gateway API CRDs → install Cilium → seed the 1Password credential for External Secrets → install ArgoCD.
4. `mise run bootstrap` ([`bootstrap/helmfile.yaml`](bootstrap/helmfile.yaml)) finishes by applying [`/gitops/root/root-app.yaml`](../gitops/root/root-app.yaml). ArgoCD then reconciles the five ApplicationSets in [`/gitops/root/`](../gitops/root/).

Cilium and ArgoCD stay on Helm - their values in [`bootstrap/`](bootstrap/) are the source of truth for those two. Everything else (cert-manager, Longhorn, metrics-server, KubeVirt, monitoring, gateways, workloads) is GitOps from day one.

## Key decisions

- Cilium replaces kube-proxy and provides Gateway API + L2 announcements. No MetalLB.
- Only Cilium and ArgoCD bootstrap imperatively; ArgoCD has no PV dependency so Longhorn comes up later via GitOps.
- Secrets come from 1Password through External Secrets. The one imperative step is the `onepassword-credentials` Secret, SOPS-encrypted in [`bootstrap/`](bootstrap/) and applied by a helmfile hook, because the `ClusterSecretStore` needs it on ESO's first reconcile. ArgoCD itself decrypts nothing - see [docs/argocd.md](docs/argocd.md#secrets).
- System extensions baked into the Talos image at install time - adding them later needs an OS upgrade.

## Layout

```
cluster/
├── README.md
├── docs/
│   ├── bootstrap.md
│   ├── argocd.md
│   └── terraform.md
├── talos/
│   ├── patches/        # controlplane.yaml, worker.yaml
│   ├── generated/      # talosctl gen config output — gitignored
│   └── secrets/        # secrets bundle + talosconfig — gitignored
└── bootstrap/
    ├── helmfile.yaml   # `mise run bootstrap`; ends by applying the root Application
    ├── namespaces.yaml
    ├── onepassword-credentials.sops.yaml
    ├── cilium-values.yaml
    ├── cilium-l2.yaml
    └── argocd-values.yaml
```

## Docs

- [bootstrap.md](docs/bootstrap.md) - step-by-step from a blank node to a working cluster.
- [argocd.md](docs/argocd.md) - app-of-apps layout, secret wiring, operating notes.
- [terraform.md](docs/terraform.md) - planned Terraform + Terragrunt replacement for Talos config and bootstrap.
- [talos/README.md](talos/README.md) - common `talosctl` commands.

## Not here yet

- etcd backup (Longhorn and Postgres backups exist: [docs/backup-restore.md](docs/backup-restore.md)).
- Non-privileged GPU device plugin (Jellyfin currently reaches `/dev/dri` via `privileged: true` as a stopgap - see [`/gitops/apps/media-stack/values.yaml`](../gitops/apps/media-stack/values.yaml)).
- Terraform + Terragrunt for Talos + bootstrap - see [docs/terraform.md](docs/terraform.md).
