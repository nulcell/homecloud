# Bootstrap

One-time, imperative bring-up of a Talos cluster: Talos → Gateway API CRDs → Cilium → 1Password credential → ArgoCD → root Application. From the root Application onward, everything lives in [`/gitops/`](../../gitops/) and reconciles automatically. See [argocd.md](argocd.md) for the post-bootstrap layout.

Steps 4-8 are one command, `mise run bootstrap`, which applies [`bootstrap/helmfile.yaml`](../bootstrap/helmfile.yaml). Versions live in that file. Re-running it is safe.

## 0. Prerequisites

Tools: `talosctl`, `kubectl`, `helm`, `helmfile`, `sops`, `age` - all pinned in [`/.mise.toml`](../../.mise.toml), `mise install` from the repo root. The age private key must be at `~/.config/sops/age/keys.txt` (backed up in 1Password) to decrypt the bootstrap credential.

Network plan - pick before you start, write down somewhere:

| Variable           | Current                   | Notes                                                         |
| ------------------ | ------------------------- | ------------------------------------------------------------- |
| Cluster name       | `homecloud`               | Anything. Used in `talosconfig`.                              |
| Node subnet        | `10.10.16.0/20`           | `nodeIP.validSubnets` + etcd advertising.                     |
| Default gateway    | `10.10.31.254`            | Also the LAN DNS server.                                      |
| Kubernetes API VIP | `10.10.25.25`             | `k8s.nulcell.com`. Baked into kubeconfig + Cilium from day 1. |
| Control plane      | `10.10.17.5`              | Talos API is per-node, never behind the VIP.                  |
| Worker             | `10.10.27.254`            |                                                               |
| Pod CIDR           | `10.244.0.0/16`           | No overlap with LAN.                                          |
| Service CIDR       | `10.96.0.0/12`            |                                                               |
| Cilium L2 LB pool  | `10.10.20.0-10.10.20.254` | Range on your LAN for LoadBalancer IPs.                       |

Hardware: BIOS virtualization on (KubeVirt needs it); Secure Boot either off, or on with a `metal-installer-secureboot` image (what this cluster uses); IPMI/out-of-band access strongly recommended.

## 1. Build a custom Talos image

Longhorn needs `iscsi-tools` and `util-linux-tools` baked in at install time - adding extensions later requires an OS upgrade.

At [factory.talos.dev](https://factory.talos.dev/), pick `Bare-metal`, latest stable, and enable:

- `siderolabs/iscsi-tools`
- `siderolabs/util-linux-tools`
- `siderolabs/{amd,intel}-ucode` matching your CPU
- `siderolabs/amdgpu` if you need GPU passthrough

Record the **schematic ID** - required for upgrades. Boot the ISO; Talos waits in maintenance mode for a config.

## 2. Generate cluster config

The full command with every flag this cluster uses is in [`../talos/README.md`](../talos/README.md). Short form:

```bash
talosctl gen config homecloud https://k8s.nulcell.com:6443 \
  --output-dir cluster/talos/generated --with-examples=false --with-docs=false
```

Outputs `controlplane.yaml`, `worker.yaml`, `talosconfig`, `secrets.yaml`. Secrets and configs are gitignored - keep them safe.

Patch each role with its file from [`patches/`](../talos/patches/) (CNI=none, kube-proxy disabled, VIP, etcd advertised subnets, kubelet server cert rotation, aggregator routing, Longhorn bind mount, hugepages, iSCSI/NVMe/VFIO kernel modules).

```bash
talosctl machineconfig patch cluster/talos/generated/controlplane.yaml \
  --patch @cluster/talos/patches/controlplane.yaml \
  --output cluster/talos/controlplane-final.yaml
```

## 3. Apply config + bootstrap etcd

Talos API (port 50000) is per-node, **not** behind the VIP - always target the node IP for `talosctl`.

```bash
talosctl apply-config --insecure --nodes 10.10.17.5 --file cluster/talos/controlplane-final.yaml

export TALOSCONFIG=$(pwd)/cluster/talos/generated/talosconfig
talosctl config endpoint 10.10.17.5
talosctl config node 10.10.17.5
talosctl health --wait-timeout 10m

talosctl bootstrap          # exactly once, on exactly one node
talosctl kubeconfig ./kubeconfig
export KUBECONFIG=$(pwd)/kubeconfig
kubectl get nodes           # Ready=False (no CNI yet) is expected
```

Repeat `apply-config` with `worker-final.yaml` for each worker, then approve any pending CSRs.

## 4-8. Core components + hand-off

```bash
mise run bootstrap
```

[`helmfile.yaml`](../bootstrap/helmfile.yaml) runs, in order:

1. **Gateway API CRDs** (cilium presync) - before Cilium so its gateway controller registers. Cilium 1.20.x targets Gateway API v1.6.x; Renovate bumps them together in the `bootstrap` PR.
2. **Cilium** ([`cilium-values.yaml`](../bootstrap/cilium-values.yaml)): `kubeProxyReplacement: true`, native routing, WireGuard pod-to-pod encryption, `bpf.hostLegacyRouting: true` (apiserver→pod aggregator routes on Talos), L2 announcements, Gateway API. Postsync applies [`cilium-l2.yaml`](../bootstrap/cilium-l2.yaml) (LB pool + announcement policy). Nodes go Ready.
3. **Namespaces + 1Password credential** (argocd presync): [`namespaces.yaml`](../bootstrap/namespaces.yaml) (`argocd` with privileged PSS labels, `external-secrets`), then `sops -d onepassword-credentials.sops.yaml | kubectl apply -f -`. ESO's `onepassword` `ClusterSecretStore` needs this *before* ArgoCD deploys ESO, or every `ExternalSecret` stalls.
4. **ArgoCD** ([`argocd-values.yaml`](../bootstrap/argocd-values.yaml)): TLS terminates at the Gateway (`server.insecure: true`); repo-server runs stock kustomize with `--enable-helm`, no CMP sidecar - see [argocd.md §Rendering](argocd.md#rendering).
5. **Root Application** (argocd postsync).

The encrypted credential is created once (and again on rotation):

```bash
kubectl create secret generic onepassword-credentials -n external-secrets \
  --from-literal=credential="$(op read 'op://homecloud/5xsyk5yefnbhsfr2rfuu62e6aq/credential')" \
  --dry-run=client -o yaml > cluster/bootstrap/onepassword-credentials.sops.yaml
sops -e -i cluster/bootstrap/onepassword-credentials.sops.yaml
```

LoadBalancer smoke test:

```bash
kubectl create deploy nginx --image=nginx
kubectl expose deploy nginx --type=LoadBalancer --port=80
kubectl get svc nginx -w    # wait for EXTERNAL-IP, then curl it
kubectl delete deploy,svc nginx
```

Initial ArgoCD admin password:

```bash
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d
# log in, change it, then:
kubectl -n argocd delete secret argocd-initial-admin-secret
```

### Root Application

It targets [`gitops/root/`](../../gitops/root/) with `directory.recurse: false`, picking up only the five ApplicationSets there - which then fan out into one Application per directory under `infrastructure/`, `operators/`, `security/`, `services/` and `apps/`. Expect ~1-2 minutes of red Applications on first sync (CRDs racing each other); `selfHeal: true` converges them.

## 9. Verify

```bash
kubectl get nodes -o wide
kubectl get pods -A | grep -vE 'Running|Completed'   # should be empty
kubectl get storageclass                             # longhorn (default)
kubectl get gateway -A                               # internal + external, PROGRAMMED=True
argocd app list
```

## Common failures

| Symptom                                    | Likely cause                            | Check                                                |
| ------------------------------------------ | --------------------------------------- | ---------------------------------------------------- |
| Node `NotReady` after Cilium install       | `k8sServiceHost/Port` not set           | `cilium-values.yaml`, then `mise run bootstrap`      |
| Longhorn manager CrashLoopBackOff          | Missing iscsi-tools / util-linux-tools  | Rebuild Talos image, `talosctl upgrade`              |
| LoadBalancer stuck `<pending>`             | L2 announcement policy wrong            | `kubectl describe ciliuml2announcementpolicy`        |
| metrics-server `unable to fetch metrics`   | Kubelet server cert not rotating        | `talosctl logs kubelet`                              |
| Every `ExternalSecret` `SecretSyncedError` | `onepassword-credentials` missing/stale | `kubectl get clustersecretstore onepassword -o yaml` |

Deeper Talos: `talosctl logs kubelet`, `talosctl logs etcd`, `talosctl dashboard`, `talosctl get members`.
