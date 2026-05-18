# Bootstrap

One-time, imperative bring-up of a single-node Talos cluster: Talos → Gateway API CRDs → Cilium → ArgoCD → root Application. From the root Application onward, everything lives in [`/gitops/`](../../gitops/) and reconciles automatically. See [argocd.md](argocd.md) for the post-bootstrap layout.

The whole script in step 8 is in [`bootstrap/install.sh`](../bootstrap/install.sh) — you can run it end-to-end after the Talos config is applied.

## 0. Prerequisites

Tools: `talosctl`, `kubectl`, `helm`, `sops`, `age`. All pinned in [`/.mise.toml`](../../.mise.toml); `mise install` from the repo root.

Network plan — pick before you start, write down somewhere:

| Variable           | Example                   | Notes                                     |
| ------------------ | ------------------------- | ----------------------------------------- |
| Cluster name       | `homecloud`               | Anything. Used in `talosconfig`.          |
| Node IP (static)   | `10.10.25.10/20`          | First control plane.                      |
| Default gateway    | `10.10.31.254`            |                                           |
| Kubernetes API VIP | `10.10.25.25`             | Baked into kubeconfig + Cilium from day 1 |
| Pod CIDR           | `10.244.0.0/16`           | No overlap with LAN.                      |
| Cilium L2 LB pool  | `10.10.20.0-10.10.20.254` | Range on your LAN for LoadBalancer IPs.   |

Hardware: BIOS virtualization on (KubeVirt needs it); Secure Boot off (or use a Secure Boot Talos image); IPMI/out-of-band access strongly recommended.

## 1. Build a custom Talos image

Longhorn needs `iscsi-tools` and `util-linux-tools` baked in at install time — adding extensions later requires an OS upgrade.

At [factory.talos.dev](https://factory.talos.dev/), pick `Bare-metal`, latest stable, and enable:

- `siderolabs/iscsi-tools`
- `siderolabs/util-linux-tools`
- `siderolabs/{amd,intel}-ucode` matching your CPU
- `siderolabs/amdgpu` if you need GPU passthrough

Record the **schematic ID** — required for upgrades. Boot the ISO; Talos waits in maintenance mode for a config.

## 2. Generate cluster config

```bash
cd cluster/talos
talosctl gen config homecloud https://10.10.25.25:6443 \
  --output-dir ./generated --with-examples=false --with-docs=false
```

Outputs `controlplane.yaml`, `worker.yaml`, `talosconfig`, `secrets.yaml`. Secrets and configs are gitignored (`cluster/talos/.gitignore`) — keep them safe.

Patch the controlplane with [`patches/controlplane.yaml`](../talos/patches/controlplane.yaml) (CNI=none, kube-proxy=disabled, VIP, etcd advertised subnets, kubelet server cert rotation, aggregator routing).

```bash
talosctl machineconfig patch generated/controlplane.yaml \
  --patch @patches/controlplane.yaml --output controlplane-final.yaml
```

## 3. Apply config + bootstrap etcd

Talos API (port 50000) is per-node, **not** behind the VIP — always target the node IP for `talosctl`.

```bash
talosctl apply-config --insecure --nodes 10.10.25.10 --file controlplane-final.yaml

export TALOSCONFIG=$(pwd)/generated/talosconfig
talosctl config endpoint 10.10.25.10
talosctl config node 10.10.25.10
talosctl health --wait-timeout 10m

talosctl bootstrap          # exactly once, on exactly one node
talosctl kubeconfig ./kubeconfig
export KUBECONFIG=$(pwd)/kubeconfig
kubectl get nodes           # Ready=False (no CNI yet) is expected
```

## 4. Gateway API CRDs

Apply before Cilium so its gateway controller can register.

```bash
kubectl apply -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.5.1/standard-install.yaml
```

Cilium 1.19.x targets Gateway API v1.4.x; bump together.

## 5. Cilium

Values in [`bootstrap/cilium-values.yaml`](../bootstrap/cilium-values.yaml). Key choices: `kubeProxyReplacement: true`, native routing on pod CIDR, WireGuard pod-to-pod encryption (`nodeEncryption: false`), `bpf.hostLegacyRouting: true` (needed for apiserver→pod aggregator routes on Talos), L2 announcements, Gateway API controller on.

```bash
helm install cilium cilium/cilium \
  --namespace kube-system --version 1.19.4 \
  --values bootstrap/cilium-values.yaml
kubectl -n kube-system rollout status ds/cilium
kubectl get nodes           # now Ready
kubectl apply -f bootstrap/cilium-l2.yaml   # LB IP pool + announcement policy
```

Smoke test:

```bash
kubectl create deploy nginx --image=nginx
kubectl expose deploy nginx --type=LoadBalancer --port=80
kubectl get svc nginx -w    # wait for EXTERNAL-IP, then curl it
kubectl delete deploy,svc nginx
```

## 6. ArgoCD

Values in [`bootstrap/argocd-values.yaml`](../bootstrap/argocd-values.yaml). TLS terminates at the Gateway (`server.insecure: true`), the repo-server mounts `argocd-sops-age` for SOPS, and the `kustomize-sops` CMP sidecar renders `.enc.yaml` + Helm chart blocks.

```bash
helm install argocd argo/argo-cd \
  --namespace argocd --create-namespace --version 9.5.14 \
  --values bootstrap/argocd-values.yaml
kubectl -n argocd rollout status deploy/argocd-server

# initial admin password
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath='{.data.password}' | base64 -d
# log in, change it, then:
kubectl -n argocd delete secret argocd-initial-admin-secret
```

## 7. SOPS

```bash
mkdir -p ~/.config/sops/age
age-keygen -o ~/.config/sops/age/keys.txt   # store the private key safely
```

Put the public key in [`/.sops.yaml`](../../.sops.yaml). Drop the private key into the cluster so the repo-server can decrypt:

```bash
kubectl -n argocd create secret generic argocd-sops-age \
  --from-file=key.txt=$HOME/.config/sops/age/keys.txt
```

If you ran [`bootstrap/install.sh`](../bootstrap/install.sh) with the age key already in place, the script created this Secret for you.

## 8. Root Application

Hands the cluster off to GitOps. Either let `install.sh` apply it as its final step, or:

```bash
kubectl apply -f gitops/root/root-app.yaml
```

It targets [`gitops/root/`](../../gitops/root/) with `directory.recurse: false`, picking up only the two ApplicationSets there — which then fan out into one Application per directory under [`gitops/infrastructure/`](../../gitops/infrastructure/) and [`gitops/apps/`](../../gitops/apps/). Expect ~1–2 minutes of red Applications on first sync (CRDs racing each other); `selfHeal: true` converges them.

## 9. Verify

```bash
kubectl get nodes -o wide
kubectl get pods -A | grep -vE 'Running|Completed'   # should be empty
kubectl get storageclass
argocd app list
```

## Common failures

| Symptom | Likely cause | Check |
| --- | --- | --- |
| Node `NotReady` after Cilium install | `k8sServiceHost/Port` not set | `cilium-values.yaml`, then `helm upgrade` |
| Longhorn manager CrashLoopBackOff | Missing iscsi-tools / util-linux-tools | Rebuild Talos image, `talosctl upgrade` |
| LoadBalancer stuck `<pending>` | L2 announcement policy wrong | `kubectl describe ciliuml2announcementpolicy` |
| metrics-server `unable to fetch metrics` | Kubelet server cert not rotating | `talosctl logs kubelet` |
| Repo-server `permission denied` on age key | `argocd-sops-age` missing | `kubectl -n argocd get secret argocd-sops-age` |

Deeper Talos: `talosctl logs kubelet`, `talosctl logs etcd`, `talosctl dashboard`, `talosctl get members`.
