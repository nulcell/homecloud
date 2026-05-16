# ArgoCD Reference

Everything ArgoCD needs to drive this cluster from the [`gitops/`](../gitops/) folder: app-of-apps layout, SOPS wiring, sync-wave conventions, and worked examples.

The cluster bootstrap in [bootstrap.md](bootstrap.md) ends with ArgoCD installed and a single `root` Application pointed at `gitops/root/`. `bootstrap/install.sh` applies the root Application for you as its final step; from there ArgoCD owns cert-manager, Longhorn, metrics-server, monitoring, gateways, and the workloads under `gitops/apps/`. This doc picks up from there.

---

## Mental model

```
   bootstrap.md (Helm, one-time)
        │
        ▼
   ArgoCD  ──watches──►  gitops/root/  (the root Application)
                              │
                              └── ApplicationSet → spawns Applications for:
                                      • gitops/infrastructure/*    (cluster-level: KubeVirt, monitoring, gateways, ...)
                                      • gitops/apps/*              (your actual workloads)
```

The repo is the source of truth. The only state ArgoCD itself owns that isn't in git is:

- The age key (in-cluster Secret only — never committed).
- The initial admin password (rotated and deleted during bootstrap).
- The Talos secrets bundle (in `talos/secrets/`, gitignored).

---

## Repository layout

```
kubernetes-infrastructure/gitops/
├── root/
│   ├── root-app.yaml                  # applied by bootstrap/install.sh (or by hand if you skipped it)
│   ├── infrastructure-appset.yaml     # ApplicationSet → one App per infrastructure/ subdir
│   └── apps-appset.yaml               # ApplicationSet → one App per apps/ subdir
├── infrastructure/
│   ├── cert-manager/                  # jetstack chart + values
│   ├── longhorn/                      # longhorn chart + namespace (privileged PSA) + values
│   ├── metrics-server/                # metrics-server chart into kube-system
│   ├── cnpg/                          # CloudNativePG operator
│   ├── kube-prometheus-stack/
│   │   ├── kustomization.yaml         # uses --enable-helm to render the chart
│   │   └── values.yaml
│   ├── gateway/
│   │   ├── gatewayclass.yaml          # CiliumGatewayClass
│   │   ├── gateway-default.yaml       # default Gateway listening on the L2-LB IP
│   │   └── clusterissuer.yaml         # cert-manager ClusterIssuer (Let's Encrypt or self-signed)
│   ├── external-dns/                  # external-dns chart, reuses Cloudflare token from gateway/
│   ├── infra-app-httproutes/          # HTTPRoutes for argocd, grafana, longhorn UIs
│   └── sops-secrets/
│       └── example-secret.enc.yaml    # demo encrypted secret
└── apps/
    └── (your workloads)
```

> Every directory under `infrastructure/` and `apps/` is expected to contain a `kustomization.yaml`. The ApplicationSets use a directory generator and discover them automatically.

---

## The root Application

Applied during bootstrap (step 8 of [bootstrap.md](bootstrap.md)) — either by `bootstrap/install.sh` automatically, or by hand if you ran the steps individually. The manifest lives at [`gitops/root/root-app.yaml`](../gitops/root/root-app.yaml).

The important bits:

- **`spec.source.path: kubernetes-infrastructure/gitops/root`** with **`directory.recurse: false`** — root-app only adopts the two ApplicationSet CRs sitting in that directory. The Applications those AppSets later generate are not children of root-app; they're created by the AppSet controller and reconcile independently.
- **`finalizers: [resources-finalizer.argocd.argoproj.io]`** — deleting the root Application cascades a clean teardown of everything below it. Useful for a deliberate wipe, dangerous if you forget about it.
- **`syncPolicy.automated.{prune,selfHeal}: true` + `ServerSideApply=true`** — the same policy is then inherited by every AppSet template, so the whole tree is self-healing by default.

---

## ApplicationSets

Two sets, one per top-level GitOps folder. Splitting them lets you put cluster-critical infra on stricter sync settings than workloads.

- [`gitops/root/infrastructure-appset.yaml`](../gitops/root/infrastructure-appset.yaml) — one Application per subdirectory of [`gitops/infrastructure/`](../gitops/infrastructure/), named `infra-<dir>`.
- [`gitops/root/apps-appset.yaml`](../gitops/root/apps-appset.yaml) — one Application per subdirectory of [`gitops/apps/`](../gitops/apps/), named `app-<dir>`.

Both share the same template shape; the things worth understanding:

- **`generators[].git.directories.path: .../*`** — wildcard directory generator. Drop a new folder under `gitops/infrastructure/` or `gitops/apps/` and an Application is auto-created on the next AppSet reconcile. Delete the folder and the Application is removed (`prune: true` cleans up the cluster resources).
- **`template.spec.source.plugin.name: kustomize-sops`** — render with the SOPS-aware kustomize plugin so `.enc.yaml` files are decrypted on the repo-server before apply.
- **`template.spec.destination.namespace: '{{.path.basename}}'`** — sets the default namespace for resources that don't declare one. Most chart-rendered manifests carry their own namespace (e.g. cnpg lands in `cnpg-system`), so the directory-name namespace mostly just creates a small empty namespace alongside the real one.
- **`template.metadata.annotations.argocd.argoproj.io/sync-wave`** — `"0"` on infra, `"10"` on apps. This annotation only orders resources **within** a single Application's sync, so AppSet-generated Applications run independently of each other (see "Cross-Application ordering" below).

### Sync waves

Within an app's manifests, set `argocd.argoproj.io/sync-wave` annotations to order resources when initial creation matters (CRDs before CRs, ClusterIssuer before Certificates, etc.):

| Wave  | Typical content                                                          |
| ----- | ------------------------------------------------------------------------ |
| `-10` | CRDs                                                                     |
| `-5`  | Namespaces, RBAC                                                         |
| `0`   | Operators / controllers                                                  |
| `5`   | Custom Resources for those operators (KubeVirt CR, Certificate, Gateway) |
| `10`  | Workloads                                                                |

### Cross-Application ordering

There is none, by design. AppSet-generated Applications each have their own reconcile loop; sync-waves only order resources inside a single Application. When `gateway` boots before cert-manager is ready (its `ClusterIssuer` references a `cert-manager.io/v1` kind that doesn't exist yet), the sync fails with `no matches for kind ClusterIssuer` — and then `selfHeal: true` retries on the next 60s tick, at which point cert-manager's CRDs are present and it succeeds. Same for `kube-prometheus-stack` PVCs waiting on Longhorn's StorageClass. First bootstrap is noisy for ~1–2 minutes; everything converges without intervention.

---

## SOPS with kustomize-sops

ArgoCD's repo-server runs `kustomize build` — to make it transparently decrypt SOPS-encrypted secrets, a Config Management Plugin (CMP) is registered as a sidecar on the repo-server.

### 1. Repo-level config

[`.sops.yaml`](../../.sops.yaml) at the repo root drives `sops --encrypt`:

- **`path_regex: kubernetes-infrastructure/.*\.enc\.ya?ml$`** — only files matching the `.enc.yaml` suffix are picked up by SOPS rules, so a stray Secret with a normal `.yaml` name will never be silently encrypted (or worse, expected to be).
- **`encrypted_regex: ^(data|stringData)$`** — only the `data`/`stringData` keys get encrypted, leaving `metadata`, `type`, etc. legible in git diffs.
- **`age: <public-key>`** — the public half of the age key you generated during bootstrap. The private half lives in `~/.config/sops/age/keys.txt` on your workstation *and* as the `argocd-sops-age` Secret inside the cluster.

Encrypt a secret in-place:

```bash
sops --encrypt --in-place gitops/infrastructure/sops-secrets/example-secret.enc.yaml
```

### 2. CMP sidecar on the repo-server

Wired up in [`bootstrap/argocd-values.yaml`](../bootstrap/argocd-values.yaml) under `repoServer.extraContainers` (the `kustomize-sops` sidecar) and `configs.cmp.plugins.kustomize-sops`. The pieces:

- **Sidecar image `viaductoss/ksops:v4.3.3`** — bundles `kustomize` + `sops` + `ksops` and runs the `argocd-cmp-server` binary so ArgoCD can RPC into it.
- **`sops-age` volume** — mounts the in-cluster Secret created during bootstrap; `SOPS_AGE_KEY_FILE=/sops/key.txt` points sops at it for decryption.
- **`custom-tools` volume** — a `download-tools` initContainer drops the `helm` binary in there and the sidecar `subPath`-mounts it onto its own `PATH`. This is what lets `kustomize build --enable-helm` shell out to Helm when rendering `helmCharts:` blocks (cnpg, cert-manager, longhorn, metrics-server, ...).
- **`configs.cmp.plugins.kustomize-sops.generate.args`** — runs `kustomize build --enable-alpha-plugins --enable-exec --load-restrictor=LoadRestrictionsNone .`. The `LoadRestrictionsNone` flag is needed by kustomizations that reference files outside their own directory (e.g. `gitops/apps/n8n` → `charts/n8n`).

The `plugin.name: kustomize-sops` in each ApplicationSet template tells ArgoCD to use this plugin instead of the built-in Helm/Kustomize renderers.

### 3. Example encrypted secret

[`gitops/infrastructure/sops-secrets/example-secret.enc.yaml`](../gitops/infrastructure/sops-secrets/example-secret.enc.yaml) is the canonical reference. Before encryption it's just a normal `Secret` with `stringData` — after `sops --encrypt --in-place`, the `stringData` block is replaced with ciphertext but the rest of the manifest stays a valid Kubernetes resource. ArgoCD decrypts at render time and applies the plaintext.

---

## Cilium Gateway example

The Gateway tier is split across two folders:

- [`gitops/infrastructure/gateway/gatewayclass.yaml`](../gitops/infrastructure/gateway/gatewayclass.yaml) — a single `GatewayClass` named `cilium` that registers `io.cilium/gateway-controller` as its handler. Cluster-scoped, defined once.
- [`gitops/infrastructure/gateway/gateway-default.yaml`](../gitops/infrastructure/gateway/gateway-default.yaml) — the `default` Gateway in the `gateway` namespace, with two listeners: plain HTTP on `:80` and HTTPS on `:443` terminating against the `wildcard-nulcell-tls` Secret that cert-manager produces. Both listeners use `allowedRoutes.namespaces.from: All` so HTTPRoutes can attach from anywhere.
- [`gitops/infrastructure/infra-app-httproutes/`](../gitops/infrastructure/infra-app-httproutes/) — per-service HTTPRoutes ([argocd.yaml](../gitops/infrastructure/infra-app-httproutes/argocd.yaml), [grafana.yaml](../gitops/infrastructure/infra-app-httproutes/grafana.yaml), [longhorn.yaml](../gitops/infrastructure/infra-app-httproutes/longhorn.yaml)). Each one attaches to `default` in the `gateway` namespace via `parentRefs` and forwards traffic to a backing Service in the app's own namespace.

The Gateway picks an IP from the `CiliumLoadBalancerIPPool` you created during bootstrap.

---

## cert-manager + Cloudflare DNS-01

`nulcell.com` is managed by Cloudflare. cert-manager solves DNS-01 challenges against the Cloudflare API, which means the cluster does **not** need to be reachable from the internet to issue certificates — wildcard certs Just Work.

You need:

1. A Cloudflare API token (scoped to **Zone → DNS → Edit** for `nulcell.com` only — do **not** use the global API key).
2. That token committed to git as a SOPS-encrypted Secret.
3. A `ClusterIssuer` pointing at it.
4. A `Certificate` (one wildcard is usually enough) that produces the Secret the Gateway references.

All three live next to the Gateway resources under [`gitops/infrastructure/gateway/`](../gitops/infrastructure/gateway/):

- [`cloudflare-token.enc.yaml`](../gitops/infrastructure/gateway/cloudflare-token.enc.yaml) — the SOPS-encrypted Secret holding the Cloudflare API token. Namespaced to `cert-manager` so the `ClusterIssuer`'s `apiTokenSecretRef` can resolve it; also referenced from [`gitops/infrastructure/external-dns/secret-generator.yaml`](../gitops/infrastructure/external-dns/secret-generator.yaml), which re-points it into the `external-dns` namespace via ksops.
- [`clusterissuer.yaml`](../gitops/infrastructure/gateway/clusterissuer.yaml) — the `letsencrypt-nulcell-com` `ClusterIssuer` against the **production** ACME endpoint. Swap the `acme.server` to `https://acme-staging-v02.api.letsencrypt.org/directory` while you're debugging the DNS-01 solver to avoid burning prod rate limits (50 certs/registered-domain/week, 5 duplicate certs/week). The `dns01.cloudflare.apiTokenSecretRef` points back at the Secret above; the `selector.dnsZones: [nulcell.com]` scopes this issuer to just that zone.
- [`wildcard-certificate.yaml`](../gitops/infrastructure/gateway/wildcard-certificate.yaml) — the `wildcard-nulcell` `Certificate` whose `secretName: wildcard-nulcell-tls` is what the Gateway listener references for TLS termination. `commonName: *.nulcell.com` plus a `dnsNames` entry covering the apex; 90-day duration with a 30-day `renewBefore`.

Use a `letsencrypt-staging` ClusterIssuer for first runs — Let's Encrypt's prod rate limit is unforgiving if you misconfigure the DNS-01 solver and burn through requests.

> **If you switch to 1Password later**: External Secrets Operator with the 1Password Connect provider can replace the SOPS-encrypted `cloudflare-api-token` Secret transparently. The `ClusterIssuer` keeps the same `apiTokenSecretRef`, so only the source of the Secret changes. SOPS is the recommended starting point — fewer moving parts, no Connect server to run.

---

## Self-managing ArgoCD

Once everything is stable, you can migrate ArgoCD's own config under GitOps so even ArgoCD upgrades are declarative:

1. Create `gitops/infrastructure/argocd/` with a kustomization that renders the same Helm chart and values as in `bootstrap/argocd-values.yaml`.
2. Apply once to make ArgoCD adopt its own Application.
3. From then on, ArgoCD reconciles itself.

This is optional and recommended only after you trust the rest of the pipeline — a bad sync that breaks ArgoCD is annoying to recover from. The same caveat applies to Cilium; the safer pattern is to leave its **install** under Helm and let ArgoCD reconcile only the parts of the network that can be re-applied without dropping the API.

---

## What ArgoCD should manage (vs. not)

| Component                           | Owner                    | Why                                                        |
| ----------------------------------- | ------------------------ | ---------------------------------------------------------- |
| Talos OS, machine config, etc.      | `talosctl` (out of band) | Image-level; can't sensibly live in K8s                    |
| Cilium install                      | Helm (bootstrap)         | Cluster network — too dangerous to sync from git initially |
| Gateway API CRDs                    | `kubectl` (bootstrap)    | Need them before Cilium starts                             |
| ArgoCD install                      | Helm (bootstrap)         | Chicken-and-egg until self-management is set up            |
| Cilium L2 IP pool / policy          | `kubectl` (bootstrap)    | Applied alongside Cilium; pure manifests                   |
| Longhorn install                    | ArgoCD                   | `gitops/infrastructure/longhorn/`                          |
| cert-manager install                | ArgoCD                   | `gitops/infrastructure/cert-manager/`                      |
| metrics-server install              | ArgoCD                   | `gitops/infrastructure/metrics-server/`                    |
| cert-manager Issuers/Certificates   | ArgoCD                   |                                                            |
| Gateway / HTTPRoute / GatewayClass  | ArgoCD                   |                                                            |
| KubeVirt operator + CR              | ArgoCD                   |                                                            |
| kube-prometheus-stack               | ArgoCD                   |                                                            |
| Application workloads               | ArgoCD                   |                                                            |
| Secrets (encrypted)                 | ArgoCD via SOPS          |                                                            |

The split favors safety in the bootstrap (the things that, if broken, lock you out of the cluster entirely) and GitOps for everything that follows. cert-manager, Longhorn, and metrics-server used to live in the bootstrap script too; they were moved into GitOps once it was clear ArgoCD itself didn't depend on them at install time.

---

## Operating notes

- **Adding a new app**: drop a kustomization under `gitops/apps/<name>/`, commit, push. The `apps` ApplicationSet picks it up automatically.
- **Removing an app**: delete the directory. With `prune: true` and the resources finalizer, ArgoCD cleans up cluster resources on the next sync.
- **Temporary divergence**: annotate an Application with `argocd.argoproj.io/sync-options: SkipDryRunOnMissingResource=true` or set `selfHeal: false` to hand-edit something while debugging.
- **CRD-first apps**: put CRDs in their own kustomization with a lower sync wave, or use `syncOptions: [Replace=true, ServerSideApply=true]`.
- **Stuck terminating resources**: `kubectl patch <kind> <name> -p '{"metadata":{"finalizers":[]}}' --type=merge` is the homelab nuclear option.

---

## References

- [ArgoCD docs](https://argo-cd.readthedocs.io/)
- [ArgoCD ApplicationSet generators](https://argo-cd.readthedocs.io/en/stable/operator-manual/applicationset/Generators/)
- [Cilium Gateway API](https://docs.cilium.io/en/stable/network/servicemesh/gateway-api/gateway-api/)
- [SOPS](https://github.com/getsops/sops)
- [kustomize-sops (ksops)](https://github.com/viaduct-ai/kustomize-sops)
- [Talos Image Factory](https://factory.talos.dev/)
