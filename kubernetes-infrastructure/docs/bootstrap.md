# Bootstrap Guide

Manual, step-by-step bootstrap of a single-node Talos cluster with Cilium, Gateway API, and Argo CD. cert-manager, Longhorn, metrics-server, monitoring, gateways, and workloads are not installed here — they come up under GitOps once ArgoCD adopts the [`gitops/`](../gitops/) folder. See [argocd.md](argocd.md) for the post-bootstrap topology.

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
helm repo add argo https://argoproj.github.io/argo-helm
helm repo update
```

> The Longhorn / jetstack / metrics-server repos are only needed at GitOps-render time inside the ArgoCD repo-server, not on your workstation.

### Plan your network

Pick values **before** you start and write them down — most of these are baked into the machine config.

| Variable           | Example                   | Notes                                                |
| ------------------ | ------------------------- | ---------------------------------------------------- |
| Cluster name       | `homecloud`               | Anything. Used in `talosconfig`.                     |
| Node hostname      | `talos-cp-01`             | Set per-node.                                        |
| LAN CIDR           | `10.10.16.0/20`           | Home network range.                                  |
| Node IP (static)   | `10.10.25.10/20`          | First control plane. /20 mask matches the LAN CIDR.  |
| Default gateway    | `10.10.31.254`            | Home gateway.                                        |
| DNS                | `10.10.31.254`, `1.1.1.1` | Home DNS first, public fallback second.              |
| Kubernetes API VIP | `10.10.25.25`             | Active from day one; baked into kubeconfig + Cilium. |
| Pod CIDR           | `10.244.0.0/16`           | No overlap with the LAN.                             |
| Service CIDR       | `10.96.0.0/12`            | Default; no overlap with the LAN.                    |
| Cilium L2 LB pool  | `10.10.20.0–10.10.20.254` | Range on your LAN for `LoadBalancer` services.       |
| Time source        | `pool.ntp.org`            | Talos needs reliable NTP.                            |

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

> Cilium 1.19.x targets Gateway API v1.4.x. If you bump either, re-check the [Cilium Gateway API support matrix](https://docs.cilium.io/en/stable/network/servicemesh/gateway-api/gateway-api/).

---

## 5. Install Cilium

Values live in [`bootstrap/cilium-values.yaml`](../bootstrap/cilium-values.yaml). The shape worth understanding before you tweak it:

- **kube-proxy replacement** (`kubeProxyReplacement: true`) is the whole reason we disabled `kube-proxy` in the Talos config. `k8sServiceHost`/`k8sServicePort` point at the **VIP** rather than the node IP so that adding more control planes later does not require a Cilium rollout.
- **Routing** is native (`routingMode: native`, `ipv4NativeRoutingCIDR: 10.244.0.0/16`, `autoDirectNodeRoutes: true`) — switch to tunnel mode only if your LAN can't carry the pod CIDR.
- **L2 LB** (`l2announcements`, `externalIPs`, the bumped `k8sClientRateLimit`) is what lets `LoadBalancer` services pick up an IP from the pool you'll define next. Leader election for L2 needs the higher client QPS/burst.
- **Gateway API** controller is enabled here (`gatewayAPI.enabled: true`); the CRDs themselves were already applied in step 4.
- **Hubble** UI + relay are on for observability — turn them off if you want less surface area.
- **Talos-specific bits**: `cgroup.autoMount.enabled: false` plus the explicit `securityContext.capabilities` block are needed because Talos manages cgroups itself and runs a tighter PSP/PSA than a stock distro.

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

Apply the L2 IP pool and announcement policy from [`bootstrap/cilium-l2.yaml`](../bootstrap/cilium-l2.yaml) so `LoadBalancer` services get IPs:

```bash
kubectl apply -f bootstrap/cilium-l2.yaml
```

What that file defines:

- A `CiliumLoadBalancerIPPool` carving out the `10.10.20.0–10.10.20.254` range from the LAN. Update the `blocks` range if your network plan differs.
- A `CiliumL2AnnouncementPolicy` that announces those IPs over any `eth*` interface on every Linux node. Tighten the interface regex or node selector if you don't want every node ARPing for LB IPs.

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

## 6. Install ArgoCD

Values live in [`bootstrap/argocd-values.yaml`](../bootstrap/argocd-values.yaml). The notable knobs:

- **`global.domain: argocd.nulcell.com`** — used in OAuth/callback URLs and matches the hostname the Gateway HTTPRoute terminates.
- **`configs.params.server.insecure: true`** — TLS is offloaded to the Cilium Gateway via the wildcard cert; running the server in plaintext inside the cluster avoids a second internal cert chain.
- **`configs.cm.kustomize.buildOptions: "--enable-helm"`** — lets ArgoCD render the `helmCharts:` blocks under `gitops/infrastructure/*` (cnpg, cert-manager, longhorn, metrics-server, ...).
- **`configs.cmp.plugins.kustomize-sops`** — registers the kustomize-sops [Config Management Plugin](https://argo-cd.readthedocs.io/en/stable/operator-manual/config-management-plugins/) that the ApplicationSets reference by name.
- **`server.service.type: LoadBalancer`** — picks up an IP from the Cilium L2 pool. `server.ingress.enabled: false` because Gateway API takes over via [`gitops/infrastructure/infra-app-httproutes/argocd.yaml`](../gitops/infrastructure/infra-app-httproutes/argocd.yaml).
- **`redis-ha.enabled: false`** and single replicas for controller/repoServer — appropriate for a single-node homelab; bump them when you go HA.
- **`repoServer.volumes` + `volumeMounts` + `env.SOPS_AGE_KEY_FILE`** — mount the `argocd-sops-age` Secret created in step 7 so the repo-server can decrypt `.enc.yaml` files at render time.
- **`repoServer.initContainers.download-tools` + `extraContainers.kustomize-sops`** — the init container downloads `helm` into a shared `custom-tools` volume that the ksops sidecar then sources via `subPath` mount. That's what lets `kustomize build` shell out to Helm when rendering the chart blocks.

Install:

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

## 7. Wire up SOPS

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

The argocd values file in step 6 already mounts this and sets `SOPS_AGE_KEY_FILE`. See [argocd.md](argocd.md) for the kustomize-sops plugin config and an example encrypted secret.

> If you ran `bootstrap/install.sh` end-to-end with the age key already present at `$HOME/.config/sops/age/keys.txt`, the script created this Secret for you before installing ArgoCD — you can skip the `kubectl create secret` above.

---

## 8. Bootstrap the GitOps root Application

This is the seam where Helm hands off to ArgoCD. `bootstrap/install.sh` applies [`gitops/root/root-app.yaml`](../gitops/root/root-app.yaml) for you as its final step; if you skipped the script, apply it by hand:

```bash
kubectl apply -f gitops/root/root-app.yaml
```

What the manifest does:

- Points at `kubernetes-infrastructure/gitops/root` with `directory.recurse: false` so the only resources it picks up are the two ApplicationSets sitting in that directory ([`infrastructure-appset.yaml`](../gitops/root/infrastructure-appset.yaml) and [`apps-appset.yaml`](../gitops/root/apps-appset.yaml)) — not the children those AppSets generate.
- Each ApplicationSet fans out into one `Application` per subdirectory of [`gitops/infrastructure/`](../gitops/infrastructure/) and [`gitops/apps/`](../gitops/apps/) — including cert-manager, Longhorn, and metrics-server.
- `syncPolicy.automated.selfHeal: true` plus the default 60s reconciliation window mean any Application that initially fails (e.g. `gateway` rendering a `ClusterIssuer` before cert-manager CRDs land) retries automatically. Expect the very first sync to show ~1–2 minutes of red Applications, then green.

From here on, anything you want in the cluster goes through git → ArgoCD. See [argocd.md](argocd.md) for the recommended layout.

---

## 9. Verify

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

| Symptom                                           | Likely cause                                                                    | Fix                                                                                                                                                             |
| ------------------------------------------------- | ------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Node `NotReady` after Cilium install              | `k8sServiceHost`/`k8sServicePort` not set, so Cilium can't reach the API server | Set them in `cilium-values.yaml` and `helm upgrade`                                                                                                             |
| Longhorn manager pods CrashLoopBackOff            | Missing `iscsi-tools` / `util-linux-tools` extensions                           | Rebuild Talos image with extensions and run `talosctl upgrade`                                                                                                  |
| `LoadBalancer` service stuck `<pending>`          | L2 announcement policy missing or wrong interface selector                      | Check `kubectl describe ciliuml2announcementpolicy`                                                                                                             |
| `metrics-server` errors `unable to fetch metrics` | Missing `--kubelet-insecure-tls` *or* kubelet server cert not rotating          | Confirm flag is set in [`gitops/infrastructure/metrics-server/values.yaml`](../gitops/infrastructure/metrics-server/values.yaml); check `talosctl logs kubelet` |
| ArgoCD repo-server `Permission denied` on age key | Secret missing or volumeMount path wrong                                        | `kubectl -n argocd describe pod -l app.kubernetes.io/name=argocd-repo-server`                                                                                   |

For deeper Talos debugging:

```bash
talosctl logs kubelet
talosctl logs etcd
talosctl dashboard
talosctl get members
```
