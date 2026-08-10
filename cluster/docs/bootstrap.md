# Bootstrap

One-time, imperative bring-up of a Talos cluster: Talos → Gateway API CRDs → Cilium → 1Password credential → ArgoCD → root Application. From the root Application onward, everything lives in [`/gitops/`](../../gitops/) and reconciles automatically. See [argocd.md](argocd.md) for the post-bootstrap layout.

Steps 4-8 are all in [`bootstrap/install.sh`](../bootstrap/install.sh) - you can run it end-to-end after the Talos config is applied. Versions live in that script; the ones quoted below match it at the time of writing.

## 0. Prerequisites

Tools: `talosctl`, `kubectl`, `helm`, `sops`, `age` - all pinned in [`/.mise.toml`](../../.mise.toml), `mise install` from the repo root. Plus the 1Password CLI (`op`, `brew install op`), which `install.sh` calls to seed the External Secrets credential.

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

## 4. Gateway API CRDs

Apply before Cilium so its gateway controller can register.

```bash
kubectl apply --server-side \
  -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.6.1/standard-install.yaml
```

Cilium 1.20.x targets Gateway API v1.6.x; bump them together.

## 5. Cilium

Values in [`bootstrap/cilium-values.yaml`](../bootstrap/cilium-values.yaml). Key choices: `kubeProxyReplacement: true`, native routing on pod CIDR, WireGuard pod-to-pod encryption (`nodeEncryption: false`), `bpf.hostLegacyRouting: true` (needed for apiserver→pod aggregator routes on Talos), L2 announcements, Gateway API controller on.

```bash
helm install cilium cilium/cilium \
  --namespace kube-system --version 1.20.0 \
  --values cluster/bootstrap/cilium-values.yaml
kubectl -n kube-system rollout status ds/cilium
kubectl get nodes           # now Ready
kubectl apply -f cluster/bootstrap/cilium-l2.yaml   # LB IP pool + announcement policy
```

Smoke test:

```bash
kubectl create deploy nginx --image=nginx
kubectl expose deploy nginx --type=LoadBalancer --port=80
kubectl get svc nginx -w    # wait for EXTERNAL-IP, then curl it
kubectl delete deploy,svc nginx
```

## 6. External Secrets credential

The `onepassword` `ClusterSecretStore` needs its service-account token to exist *before* ArgoCD deploys ESO, otherwise the store fails its first reconcile and every dependent `ExternalSecret` stalls.

```bash
kubectl create namespace external-secrets
kubectl -n external-secrets create secret generic onepassword-credentials \
  --from-literal=credential="$(op read 'op://homecloud/5xsyk5yefnbhsfr2rfuu62e6aq/credential')"
```

`install.sh` does this idempotently - it skips the secret if it already exists.

## 7. ArgoCD

Values in [`bootstrap/argocd-values.yaml`](../bootstrap/argocd-values.yaml). TLS terminates at the Gateway (`server.insecure: true`); the repo-server runs stock kustomize with `--enable-helm --load-restrictor=LoadRestrictionsNone`. No CMP sidecar - see [argocd.md §Rendering](argocd.md#rendering).

The `argocd` namespace needs `pod-security.kubernetes.io/enforce: privileged` labels, which `install.sh` applies before the Helm install.

```bash
helm install argocd argo/argo-cd \
  --namespace argocd --create-namespace --version 10.3.0 \
  --values cluster/bootstrap/argocd-values.yaml
kubectl -n argocd rollout status deploy/argocd-server

# initial admin password
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath='{.data.password}' | base64 -d
# log in, change it, then:
kubectl -n argocd delete secret argocd-initial-admin-secret
```

## 8. Root Application

Hands the cluster off to GitOps. Either let `install.sh` apply it as its final step, or:

```bash
kubectl apply -f gitops/root/root-app.yaml
```

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
| Node `NotReady` after Cilium install       | `k8sServiceHost/Port` not set           | `cilium-values.yaml`, then `helm upgrade`            |
| Longhorn manager CrashLoopBackOff          | Missing iscsi-tools / util-linux-tools  | Rebuild Talos image, `talosctl upgrade`              |
| LoadBalancer stuck `<pending>`             | L2 announcement policy wrong            | `kubectl describe ciliuml2announcementpolicy`        |
| metrics-server `unable to fetch metrics`   | Kubelet server cert not rotating        | `talosctl logs kubelet`                              |
| Every `ExternalSecret` `SecretSyncedError` | `onepassword-credentials` missing/stale | `kubectl get clustersecretstore onepassword -o yaml` |
| App `OutOfSync` on a `chartHome` path      | Load restrictor not relaxed             | `kustomize.buildOptions` in `argocd-values.yaml`     |

Deeper Talos: `talosctl logs kubelet`, `talosctl logs etcd`, `talosctl dashboard`, `talosctl get members`.
