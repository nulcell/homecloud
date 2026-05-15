# Bootstrap Guide

Manual, step-by-step bootstrap of a single-node Talos cluster with Cilium, Longhorn, cert-manager, metrics-server, Gateway API, and Argo CD. After this guide, ArgoCD will be ready to manage everything else from the [`gitops/`](../gitops/) folder — see [argocd.md](argocd.md).

> Time estimate: ~60–90 min the first time, mostly waiting on images.

---

## 0. Prerequisites

### Tools on your workstation

| Tool                                                                                                        | Purpose                                  |
| ----------------------------------------------------------------------------------------------------------- | ---------------------------------------- |
| [`talosctl`](https://www.talos.dev/latest/talos-guides/install/talosctl/)                                   | Manage Talos nodes                       |
| [`kubectl`](https://kubernetes.io/docs/tasks/tools/)                                                        | Manage Kubernetes                        |
| [`helm`](https://helm.sh/docs/intro/install/) v3                                                            | Install core components                  |
| [`sops`](https://github.com/getsops/sops/releases) and [`age`](https://github.com/FiloSottile/age/releases) | Encrypted secrets (used later by ArgoCD) |
| [`yq`](https://github.com/mikefarah/yq) (optional)                                                          | YAML patching from the shell             |

Install on macOS:

```bash
brew install siderolabs/tap/talosctl kubectl helm sops age yq
```

Add the chart repos you'll need:

```bash
helm repo add cilium https://helm.cilium.io
helm repo add longhorn https://charts.longhorn.io
helm repo add jetstack https://charts.jetstack.io
helm repo add metrics-server https://kubernetes-sigs.github.io/metrics-server
helm repo add argo https://argoproj.github.io/argo-helm
helm repo update
```

### Plan your network

Pick values **before** you start and write them down — most of these are baked into the machine config.

| Variable           | Example                     | Notes                                                |
| ------------------ | --------------------------- | ---------------------------------------------------- |
| Cluster name       | `homecloud`                 | Anything. Used in `talosconfig`.                     |
| Node hostname      | `talos-cp-01`               | Set per-node.                                        |
| LAN CIDR           | `10.10.16.0/20`             | Home network range.                                  |
| Node IP (static)   | `10.10.25.10/20`            | First control plane. /20 mask matches the LAN CIDR.  |
| Default gateway    | `10.10.31.254`              | Home gateway.                                        |
| DNS                | `10.10.31.254`, `1.1.1.1`   | Home DNS first, public fallback second.              |
| Kubernetes API VIP | `10.10.25.25`               | Active from day one; baked into kubeconfig + Cilium. |
| Pod CIDR           | `10.244.0.0/16`             | No overlap with the LAN.                             |
| Service CIDR       | `10.96.0.0/12`              | Default; no overlap with the LAN.                    |
| Cilium L2 LB pool  | `10.10.20.0–10.10.20.254`   | Range on your LAN for `LoadBalancer` services.       |
| Time source        | `pool.ntp.org`              | Talos needs reliable NTP.                            |

### Hardware sanity check

- CPU virtualization enabled in BIOS (Intel VT-x / AMD-V) — needed for KubeVirt.
- Disable Secure Boot for the install, or use a [Secure Boot-compatible Talos image](https://www.talos.dev/latest/talos-guides/install/boot-assets/).
- A separate disk (or partition) for Longhorn data is nice but not required.
- IPMI / out-of-band access is highly recommended — if you misconfigure networking you'll need console access.

---

## 1. Build a custom Talos image

Longhorn requires the `iscsi-tools` and `util-linux-tools` system extensions, and these must be baked into the OS image at install time.

1. Open [factory.talos.dev](https://factory.talos.dev/).
2. Hardware type: `Bare-metal Machine`.
3. Architecture: `amd64` (or `arm64` if your hardware is ARM).
4. Select the latest stable Talos version.
5. System extensions — enable:
   - `siderolabs/iscsi-tools`
   - `siderolabs/util-linux-tools`
   - *(Optional)* `siderolabs/intel-ucode` or `siderolabs/amd-ucode` matching your CPU.
6. Customization: leave kernel args default unless you have a specific need.
7. Note the **schematic ID** — you'll need it for upgrades.
8. Download the **ISO** (or PXE assets if you use MaaS).

Burn the ISO to USB and boot the node. Talos boots into maintenance mode and waits for a config to be applied.

---

## 2. Generate cluster configuration

On your workstation:

```bash
cd kubernetes-infrastructure/talos

# Endpoint = the API VIP. This goes into the kubeconfig and the API server cert
# SANs, so once we set it here we never have to rewrite either when more control
# planes join. Talos itself is reached via the node IP (Talos API, port 50000),
# NOT the VIP — only the Kubernetes API (6443) is fronted by the VIP.
talosctl gen config homecloud https://10.10.25.25:6443 \
  --output-dir ./generated \
  --with-examples=false \
  --with-docs=false
```

This produces `controlplane.yaml`, `worker.yaml`, `talosconfig`, and a `secrets.yaml` bundle. **Keep `secrets.yaml` and `talosconfig` out of git** — add them to `.gitignore`. The generated `controlplane.yaml` should not be edited directly; we'll patch it.

### Patches

Create [`talos/patches/controlplane.yaml`](../talos/patches/controlplane.yaml) with the things Cilium needs and the single-node allowances:

```yaml
# talos/patches/controlplane.yaml
machine:
  network:
    hostname: talos-cp-01
    interfaces:
      - interface: eth0          # adjust to your NIC; check with `talosctl get links`
        addresses:
          - 10.10.25.10/20
        routes:
          - network: 0.0.0.0/0
            gateway: 10.10.31.254
        vip:
          ip: 10.10.25.25        # API VIP — shared across control planes via etcd election
    nameservers:
      - 10.10.31.254
      - 1.1.1.1
  time:
    servers:
      - pool.ntp.org
  kubelet:
    extraArgs:
      rotate-server-certificates: "true"
cluster:
  allowSchedulingOnControlPlanes: true   # single-node phase
  network:
    cni:
      name: none                         # Cilium replaces the built-in CNI
    podSubnets:
      - 10.244.0.0/16
    serviceSubnets:
      - 10.96.0.0/12
  proxy:
    disabled: true                       # Cilium replaces kube-proxy
  apiServer:
    certSANs:                            # cert must be valid for every IP clients might use
      - 10.10.25.25                      # the VIP
      - 10.10.25.10                      # node #1
      - 10.10.25.11                      # node #2 (future)
      - 10.10.25.12                      # node #3 (future)
    extraArgs:
      feature-gates: ""
  discovery:
    enabled: true
  etcd:
    advertisedSubnets:
      - 10.10.16.0/20
```

> **Why each line matters:**
>
> - `cni.name: none` + `proxy.disabled: true` are non-negotiable for Cilium replacing both.
> - `allowSchedulingOnControlPlanes` lets workloads run on the only node you have.
> - `vip.ip` + `apiServer.certSANs` make the VIP usable from day one. Talos handles the IP via etcd-coordinated leader election; whichever control plane holds the lease answers ARP for it.
> - `etcd.advertisedSubnets` keeps etcd peers on your LAN once you have multiple control planes.
> - `rotate-server-certificates` lets the metrics-server scrape kubelets cleanly.
>
> **VIP lifecycle gotcha**: the VIP comes up *after* etcd, so during the very first bootstrap the node won't answer on the VIP yet. That's why `talosctl apply-config` and `talosctl bootstrap` in step 3 below target the **node IP** directly — the VIP only starts working once the API server is healthy.

Apply the patch and produce the final machine config:

```bash
talosctl machineconfig patch generated/controlplane.yaml \
  --patch @patches/controlplane.yaml \
  --output controlplane-final.yaml
```

---

## 3. Apply the config and bootstrap

```bash
# Apply config to the node (it's still in maintenance mode — VIP isn't up yet)
talosctl apply-config \
  --insecure \
  --nodes 10.10.25.10 \
  --file controlplane-final.yaml

# Point talosctl at the new cluster. The Talos API (port 50000) is per-node,
# NOT behind the VIP — always use real node IPs here.
export TALOSCONFIG=$(pwd)/generated/talosconfig
talosctl config endpoint 10.10.25.10
talosctl config node 10.10.25.10

# Wait for the node to settle (it reboots into the configured OS)
talosctl health --wait-timeout 10m
```

Bootstrap etcd — **do this exactly once, on exactly one node** (still targeting the node IP; the VIP becomes active right after this):

```bash
talosctl bootstrap
```

Pull the kubeconfig. It was generated with the VIP as the server URL, so kubectl talks to the cluster via `https://10.10.25.25:6443` from here on:

```bash
talosctl kubeconfig ./kubeconfig
export KUBECONFIG=$(pwd)/kubeconfig
kubectl get nodes
```

Expected: one node, `Ready=False` because there's no CNI yet. That's correct.

---

## 4. Install Gateway API CRDs

Cilium consumes these CRDs; install them before Cilium so the gateway controller can register.

```bash
kubectl apply -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.5.1/standard-install.yaml
kubectl apply -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.5.1/experimental-install.yaml  # for TLSRoute, optional
```

> Cilium 1.19.x targets Gateway API v1.5.x. If you bump either, re-check the [Cilium Gateway API support matrix](https://docs.cilium.io/en/stable/network/servicemesh/gateway-api/gateway-api/).

---

## 5. Install Cilium

Save [`bootstrap/cilium-values.yaml`](../bootstrap/cilium-values.yaml):

```yaml
# bootstrap/cilium-values.yaml
kubeProxyReplacement: true

# Required because kube-proxy is gone — Cilium needs to know how to reach the API server.
# Use the VIP, not the node IP, so HA expansion doesn't require a Cilium rollout.
k8sServiceHost: 10.10.25.25
k8sServicePort: 6443

ipam:
  mode: kubernetes

routingMode: native            # or "tunnel" if your LAN can't carry pod CIDRs
ipv4NativeRoutingCIDR: 10.244.0.0/16
autoDirectNodeRoutes: true
bpf:
  masquerade: true

l2announcements:
  enabled: true
externalIPs:
  enabled: true

# Required by L2 announcements — bumps the rate limits so leader election works.
k8sClientRateLimit:
  qps: 50
  burst: 200

gatewayAPI:
  enabled: true

operator:
  replicas: 1                  # single node

hubble:
  enabled: true
  relay:
    enabled: true
  ui:
    enabled: true

# Talos-specific: cgroup v2 is on, kube-proxy is off; this avoids a stale mount.
cgroup:
  autoMount:
    enabled: false
  hostRoot: /sys/fs/cgroup
securityContext:
  capabilities:
    ciliumAgent:
      - CHOWN
      - KILL
      - NET_ADMIN
      - NET_RAW
      - IPC_LOCK
      - SYS_ADMIN
      - SYS_RESOURCE
      - DAC_OVERRIDE
      - FOWNER
      - SETGID
      - SETUID
    cleanCiliumState:
      - NET_ADMIN
      - SYS_ADMIN
      - SYS_RESOURCE
```

Install:

```bash
helm install cilium cilium/cilium \
  --namespace kube-system \
  --version 1.19.4 \
  --values bootstrap/cilium-values.yaml

# Wait for it
kubectl -n kube-system rollout status ds/cilium
kubectl get nodes   # should now be Ready
```

Create an L2 IP pool and announcement policy so `LoadBalancer` services get IPs:

```yaml
# bootstrap/cilium-l2.yaml
apiVersion: "cilium.io/v2alpha1"
kind: CiliumLoadBalancerIPPool
metadata:
  name: home-lan
spec:
  blocks:
    - start: 10.10.20.0
      stop: 10.10.20.254
---
apiVersion: "cilium.io/v2alpha1"
kind: CiliumL2AnnouncementPolicy
metadata:
  name: home-lan
spec:
  loadBalancerIPs: true
  interfaces:
    - ^eth.+
  nodeSelector:
    matchLabels:
      kubernetes.io/os: linux
```

```bash
kubectl apply -f bootstrap/cilium-l2.yaml
```

Smoke test:

```bash
kubectl create deploy nginx --image=nginx
kubectl expose deploy nginx --type=LoadBalancer --port=80
kubectl get svc nginx -w   # wait for an EXTERNAL-IP from the pool
curl http://<that-ip>      # should return the nginx welcome page
kubectl delete deploy,svc nginx
```

If this works, networking is sound.

---

## 6. Install cert-manager

Longhorn's webhooks and KubeVirt later both want a working cert-manager, so install it before Longhorn. It will also serve as the issuer for `nulcell.com` Let's Encrypt certificates via Cloudflare DNS-01 — the [`ClusterIssuer` and `Certificate`](argocd.md#cert-manager--cloudflare-dns-01) are defined under GitOps once ArgoCD is up.

```yaml
# bootstrap/cert-manager-values.yaml
crds:
  enabled: true
prometheus:
  enabled: false   # turn on after kube-prometheus-stack is in
```

```bash
helm install cert-manager jetstack/cert-manager \
  --namespace cert-manager --create-namespace \
  --version v1.20.2 \
  --values bootstrap/cert-manager-values.yaml

kubectl -n cert-manager rollout status deploy/cert-manager-webhook
```

---

## 7. Install Longhorn

```yaml
# bootstrap/longhorn-values.yaml
defaultSettings:
  defaultReplicaCount: 1            # raise to 3 when you have 3 nodes
  defaultDataPath: /var/lib/longhorn
  storageMinimalAvailablePercentage: 10
  allowRecurringJobWhileVolumeDetached: true
persistence:
  defaultClass: true
  defaultClassReplicaCount: 1
  reclaimPolicy: Retain
ingress:
  enabled: false                    # we'll expose via Gateway later
```

Talos exposes the `/var/lib/longhorn` path as an `extraMount` if you need a dedicated disk — for the default ephemeral case, the values above are fine.

```bash
helm install longhorn longhorn/longhorn \
  --namespace longhorn-system --create-namespace \
  --version 1.11.2 \
  --values bootstrap/longhorn-values.yaml

kubectl -n longhorn-system rollout status deploy/longhorn-manager   # may take a few minutes
kubectl get storageclass                                            # 'longhorn' should be default
```

Smoke test:

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: longhorn-smoke
spec:
  accessModes: [ReadWriteOnce]
  resources:
    requests:
      storage: 1Gi
EOF

kubectl get pvc longhorn-smoke -w   # wait for Bound
kubectl delete pvc longhorn-smoke
```

---

## 8. Install metrics-server

```yaml
# bootstrap/metrics-server-values.yaml
args:
  - --kubelet-insecure-tls          # Talos kubelet certs aren't in the default trust path
  - --kubelet-preferred-address-types=InternalIP,Hostname,InternalDNS,ExternalDNS,ExternalIP
```

```bash
helm install metrics-server metrics-server/metrics-server \
  --namespace kube-system \
  --version 3.13.0 \
  --values bootstrap/metrics-server-values.yaml

kubectl top nodes   # should return values within a minute
```

> Once the cluster is stable, swap `--kubelet-insecure-tls` for proper certs by enabling kubelet server cert rotation (already on via the patch in step 2) and trusting the cluster CA.

---

## 9. Install ArgoCD

```yaml
# bootstrap/argocd-values.yaml
global:
  domain: argocd.home.lab           # adjust to your domain; used in callbacks

configs:
  params:
    server.insecure: true           # TLS terminated at the Gateway later
  cm:
    timeout.reconciliation: 60s
    kustomize.buildOptions: "--enable-helm"

server:
  service:
    type: LoadBalancer              # gets an IP from the Cilium L2 pool
  ingress:
    enabled: false                  # we'll add a Gateway HTTPRoute in gitops/

redis-ha:
  enabled: false                    # single-node; HA Redis is wasteful here

controller:
  replicas: 1

repoServer:
  replicas: 1

dex:
  enabled: false                    # add later if you want SSO

# Sync key inputs for ArgoCD-managed SOPS decryption.
# Mount the age key as a secret named `argocd-sops-age` (created in step 11).
repoServer:
  volumes:
    - name: sops-age
      secret:
        secretName: argocd-sops-age
  volumeMounts:
    - name: sops-age
      mountPath: /sops
      readOnly: true
  env:
    - name: SOPS_AGE_KEY_FILE
      value: /sops/key.txt
```

```bash
helm install argocd argo/argo-cd \
  --namespace argocd --create-namespace \
  --version 9.5.14 \
  --values bootstrap/argocd-values.yaml

kubectl -n argocd rollout status deploy/argocd-server
kubectl -n argocd get svc argocd-server   # note the EXTERNAL-IP
```

Grab the initial admin password:

```bash
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath='{.data.password}' | base64 -d
```

Log in and **change the password immediately**:

```bash
argocd login <EXTERNAL-IP>
argocd account update-password
kubectl -n argocd delete secret argocd-initial-admin-secret
```

---

## 10. Wire up SOPS

Generate an age key (do this on your workstation, store it somewhere safe — losing it means losing all encrypted secrets in this repo):

```bash
mkdir -p ~/.config/sops/age
age-keygen -o ~/.config/sops/age/keys.txt
```

The **public key** goes in [`.sops.yaml`](../../.sops.yaml) at the repo root so anyone can encrypt to it; the **private key** stays on your workstation and is also synced into the cluster so ArgoCD can decrypt at sync time.

Create the in-cluster secret:

```bash
kubectl -n argocd create secret generic argocd-sops-age \
  --from-file=key.txt=$HOME/.config/sops/age/keys.txt
```

The argocd values file in step 9 already mounts this and sets `SOPS_AGE_KEY_FILE`. See [argocd.md](argocd.md) for the kustomize-sops plugin config and an example encrypted secret.

---

## 11. Bootstrap the GitOps root Application

This is the seam where Helm hands off to ArgoCD:

```yaml
# gitops/root/root-app.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: root
  namespace: argocd
  finalizers:
    - resources-finalizer.argocd.argoproj.io
spec:
  project: default
  source:
    repoURL: https://github.com/<you>/homecloud
    targetRevision: main
    path: kubernetes-infrastructure/gitops/root
  destination:
    server: https://kubernetes.default.svc
    namespace: argocd
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
      - ServerSideApply=true
```

```bash
kubectl apply -f gitops/root/root-app.yaml
```

From here on, anything you want in the cluster goes through git → ArgoCD. See [argocd.md](argocd.md) for the recommended app-of-apps layout.

---

## 12. Verify

```bash
kubectl get nodes -o wide
kubectl get pods -A | grep -vE 'Running|Completed'   # should be empty
kubectl get storageclass
kubectl top nodes
argocd app list
```

If all of that looks healthy, you're done with the bootstrap. The next thing to add via GitOps is KubeVirt and your monitoring stack — both are documented in [argocd.md](argocd.md).

---

## Common failure modes

| Symptom                                           | Likely cause                                                                    | Fix                                                                           |
| ------------------------------------------------- | ------------------------------------------------------------------------------- | ----------------------------------------------------------------------------- |
| Node `NotReady` after Cilium install              | `k8sServiceHost`/`k8sServicePort` not set, so Cilium can't reach the API server | Set them in `cilium-values.yaml` and `helm upgrade`                           |
| Longhorn manager pods CrashLoopBackOff            | Missing `iscsi-tools` / `util-linux-tools` extensions                           | Rebuild Talos image with extensions and run `talosctl upgrade`                |
| `LoadBalancer` service stuck `<pending>`          | L2 announcement policy missing or wrong interface selector                      | Check `kubectl describe ciliuml2announcementpolicy`                           |
| `metrics-server` errors `unable to fetch metrics` | Missing `--kubelet-insecure-tls` *or* kubelet server cert not rotating          | Confirm flag is set; check `talosctl logs kubelet`                            |
| ArgoCD repo-server `Permission denied` on age key | Secret missing or volumeMount path wrong                                        | `kubectl -n argocd describe pod -l app.kubernetes.io/name=argocd-repo-server` |

For deeper Talos debugging:

```bash
talosctl logs kubelet
talosctl logs etcd
talosctl dashboard
talosctl get members
```
