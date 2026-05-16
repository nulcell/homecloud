# Kubernetes Infrastructure

A bare-metal Kubernetes homelab built on Talos Linux, intended as a long-running platform for self-hosted workloads and VMs.

## Goals

- Run on bare metal (no underlying hypervisor — KubeVirt provides VMs on top of Kubernetes).
- GitOps-managed workloads via ArgoCD reading from this repo.
- Start single-node, grow to a 3-node HA control plane.
- Treat the cluster as a long-lived platform, not a throwaway lab.

## Stack

| Layer              | Component                                                                                                                                                                                | Role                                                                |
| ------------------ | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------- |
| OS                 | [Talos Linux](https://www.talos.dev/)                                                                                                                                                    | Immutable, API-managed Kubernetes OS                                |
| CNI / LB / Gateway | [Cilium](https://cilium.io/)                                                                                                                                                             | CNI, kube-proxy replacement, L2 announcements, Gateway API provider |
| Storage            | [Longhorn](https://longhorn.io/)                                                                                                                                                         | Replicated block storage                                            |
| Virtualization     | [KubeVirt](https://kubevirt.io/)                                                                                                                                                         | VMs as Kubernetes resources                                         |
| GitOps             | [Argo CD](https://argo-cd.readthedocs.io/)                                                                                                                                               | Declarative app delivery from this repo                             |
| Certificates       | [cert-manager](https://cert-manager.io/)                                                                                                                                                 | Internal CA + ACME                                                  |
| Metrics            | [metrics-server](https://github.com/kubernetes-sigs/metrics-server), [kube-prometheus-stack](https://github.com/prometheus-community/helm-charts/tree/main/charts/kube-prometheus-stack) | Resource metrics + monitoring                                       |
| Secrets in Git     | [SOPS](https://github.com/getsops/sops) + [age](https://github.com/FiloSottile/age)                                                                                                      | Encrypted manifests in-repo                                         |

## Topology

**Phase 1 — single node**

- 1 control plane, scheduling enabled on it (`allowSchedulingOnControlPlanes: true`).
- Longhorn runs with 1 replica per volume (single point of failure — accepted for this phase).
- etcd quorum = 1 (any reboot is downtime).

**Phase 2 — 3-node HA control plane**

- Skip the 2-node intermediate state. 2-node etcd is *worse* than 1-node: both must be up for quorum.
- When ready, add two more control planes at once, raise Longhorn default replicas to 3, and remove the control-plane scheduling allowance (or keep it if all nodes are also expected to run workloads).

**Phase 3 (optional) — dedicated workers**

- Add worker nodes for capacity. Control planes can stop running workloads at that point.

## Bootstrap order

Imperative seed (one-time, via Helm and `talosctl`), then ArgoCD takes over:

1. Build a custom Talos image at [Image Factory](https://factory.talos.dev/) with `siderolabs/iscsi-tools` and `siderolabs/util-linux-tools` (required by Longhorn), plus a CPU-matching microcode extension (`amd-ucode` / `intel-ucode`) and `siderolabs/amdgpu` if you need GPU pass-through. The full step-by-step is in [docs/bootstrap.md §1](docs/bootstrap.md#1-build-a-custom-talos-image).
2. Boot the node, generate cluster config, apply with `talosctl`.
3. `talosctl bootstrap` to start etcd.
4. Helm install: Gateway API CRDs → Cilium → ArgoCD.
5. `bootstrap/install.sh` finishes by applying the ArgoCD `root` Application that points at [`gitops/`](gitops/). ArgoCD then reconciles cert-manager, Longhorn, metrics-server, and everything else under [`gitops/infrastructure/`](gitops/infrastructure/) and [`gitops/apps/`](gitops/apps/).

After bootstrap, everything *except* the Talos OS itself is described in this repo. Cilium and ArgoCD are kept under Helm at install time (their values live in [`bootstrap/`](bootstrap/) for repeatability); cert-manager, Longhorn, metrics-server, monitoring, gateways, and workloads are GitOps from day one.

## Key decisions

- **Cilium replaces kube-proxy and provides Gateway API + L2 announcements.** No MetalLB.
- **Only Cilium and ArgoCD are bootstrapped imperatively.** ArgoCD itself has no persistent-storage requirement, so Longhorn doesn't need to exist before it. cert-manager, Longhorn, and metrics-server come up via GitOps after the root Application is applied; downstream apps that depend on them (kube-prometheus-stack PVCs, the Cloudflare `ClusterIssuer`) self-heal within a couple of retry cycles.
- **SOPS + age** for secrets in Git. Solo-operator friendly, no extra cluster components on the read path beyond an ArgoCD plugin.
- **1 → 3 control-plane jump.** Avoids the 2-node split-brain trap.
- **System extensions baked into the Talos image at install time.** Adding them later requires an OS upgrade.

## Planned repo layout

```txt
kubernetes-infrastructure/
├── README.md                 # this file
├── docs/
│   ├── bootstrap.md          # step-by-step manual bootstrap
│   └── argocd.md             # ArgoCD app-of-apps + SOPS reference
├── talos/
│   ├── patches/              # machine-config patches (CNI=none, proxy=disabled, ...)
│   └── secrets/              # talosconfig + secrets bundle (gitignored)
├── bootstrap/
│   ├── cilium-values.yaml
│   ├── cilium-l2.yaml
│   ├── argocd-values.yaml
│   └── install.sh            # idempotent helm-install script; also applies the root Application
└── gitops/
    ├── root/                 # the root Application + ApplicationSets that fan out to infra/apps
    ├── infrastructure/       # cert-manager, Longhorn, metrics-server, gateways, monitoring, KubeVirt, ...
    └── apps/                 # actual workloads
```

## Documentation

- [Bootstrap guide](docs/bootstrap.md) — step-by-step from a blank node to a working cluster with all core components.
- [ArgoCD reference](docs/argocd.md) — app-of-apps layout, SOPS setup, and what ArgoCD owns.

## What's intentionally not here yet

- Actual workloads — they'll be added under `gitops/apps/` once the platform is stable.
- KubeVirt — installable any time after cert-manager is up; deferred to the GitOps phase.
- Backup strategy for etcd and Longhorn — to be added before this cluster holds anything important.
