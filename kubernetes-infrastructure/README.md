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

1. Build a custom Talos image with `iscsi-tools` and `util-linux-tools` system extensions ([Image Factory](https://factory.talos.dev/)).

    ```yaml
    customization:
        systemExtensions:
            officialExtensions:
                - siderolabs/amd-ucode
                - siderolabs/amdgpu
                - siderolabs/iscsi-tools
                - siderolabs/util-linux-tools
    ```

2. Boot the node, generate cluster config, apply with `talosctl`.
3. `talosctl bootstrap` to start etcd.
4. Helm install: Gateway API CRDs → Cilium → cert-manager → Longhorn → metrics-server → ArgoCD.
5. Apply the ArgoCD `root` Application that points at [`gitops/`](gitops/) — ArgoCD takes over.

After bootstrap, everything *except* the Talos OS itself is described in this repo. Cilium / Longhorn / cert-manager / ArgoCD are kept under Helm at install time but their values live in [`bootstrap/`](bootstrap/) for repeatability; their **upgrades** can be migrated into ArgoCD later if you want them under GitOps.

## Key decisions

- **Cilium replaces kube-proxy and provides Gateway API + L2 announcements.** No MetalLB.
- **Longhorn before ArgoCD.** ArgoCD doesn't strictly need persistent storage, but Prometheus/Grafana and future workloads do — provisioning a storage class up front avoids pending PVCs on day one.
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
│   ├── longhorn-values.yaml
│   ├── cert-manager-values.yaml
│   ├── metrics-server-values.yaml
│   ├── argocd-values.yaml
│   └── install.sh            # idempotent helm-install script
└── gitops/
    ├── root/                 # the root Application that ArgoCD bootstraps from
    ├── infrastructure/       # cert-manager extras, KubeVirt, monitoring, gateways
    └── apps/                 # actual workloads (added later)
```

## Documentation

- [Bootstrap guide](docs/bootstrap.md) — step-by-step from a blank node to a working cluster with all core components.
- [ArgoCD reference](docs/argocd.md) — app-of-apps layout, SOPS setup, and what ArgoCD owns.

## What's intentionally not here yet

- Actual workloads — they'll be added under `gitops/apps/` once the platform is stable.
- KubeVirt — installable any time after cert-manager is up; deferred to the GitOps phase.
- Backup strategy for etcd and Longhorn — to be added before this cluster holds anything important.
