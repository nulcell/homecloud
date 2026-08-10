# ArgoCD

Everything ArgoCD owns after [bootstrap](bootstrap.md): app-of-apps layout, secret wiring, sync ordering.

## Mental model

```
bootstrap (Helm)
   │
   ▼
ArgoCD ──watches──► gitops/root/   (root Application, directory.recurse=false)
                          │
                          └── five ApplicationSets, one Application per directory under:
                                • gitops/infrastructure/*  → infra-*      (wave 0)
                                • gitops/operators/*       → operators-*  (wave 5)
                                • gitops/security/*        → sec-*        (wave 10)
                                • gitops/services/*        → services-*   (wave 15)
                                • gitops/apps/*            → app-*        (wave 100)
```

Source of truth = this repo. Cluster state ArgoCD does *not* own: the `onepassword-credentials` Secret seeded by `install.sh`, and the rotated admin password.

## Layout

```
gitops/
├── root/
│   ├── root-app.yaml               # applied once by bootstrap/install.sh
│   ├── infrastructure-appset.yaml
│   ├── operators-appset.yaml
│   ├── security-appset.yaml
│   ├── services-appset.yaml
│   └── apps-appset.yaml
├── infrastructure/   # cert-manager, external-dns, external-secrets, gateway, headlamp,
│                     # infra-app-httproutes, kube-prometheus-stack, loki, longhorn,
│                     # metrics-server, registry-credentials
├── operators/        # cnpg, falco, kubevirt, mariadb, tailscale
├── security/         # falco
├── services/         # kubevirt (KubeVirt + CDI CRs)
├── apps/             # actual-budget, authentik, cloudflared, mealie, media-stack,
│                     # n8n, portfolio, uptime-kuma
└── exprimental/      # staging area — no ApplicationSet reads this, nothing here runs
```

Every directory under the five generated paths must contain a `kustomization.yaml` - the ApplicationSets pick them up automatically. The generated Application's destination namespace is the directory basename.

## Sync ordering

Two independent mechanisms, easy to confuse:

- **Per-Application waves.** Each ApplicationSet template stamps a fixed `argocd.argoproj.io/sync-wave` on the Applications it generates (0 / 5 / 10 / 15 / 100 above), so the root Application rolls the layers out in order.
- **Within one Application**, `argocd.argoproj.io/sync-wave` on individual resources orders them against each other - CRDs before namespaces before CRs. AppSet-generated Applications otherwise reconcile independently.

When an Application sync fails because another Application's CRDs aren't there yet, `selfHeal: true` retries every 60s. First bootstrap is noisy for ~1-2 minutes then converges.

All generated Applications run `automated: {prune: true, selfHeal: true}` with `CreateNamespace=true` and `ServerSideApply=true`.

Two notable overrides:

- `apps-appset.yaml` sets `compare-options: ServerSideDiff=true`, so CRD schema defaults the API server injects (e.g. relabelings `action: replace`) don't read as permanent drift.
- `operators-appset.yaml` ignores `/spec/versions` on `cdis.cdi.kubevirt.io` and sets `RespectIgnoreDifferences=true`. cdi-operator strips `v1alpha1` from that CRD; without this ArgoCD puts it back every reconcile, and each flip leaks etcd connections in the apiserver.

## Rendering

No config management plugin. The repo-server runs stock kustomize with build options set in [`bootstrap/argocd-values.yaml`](../bootstrap/argocd-values.yaml):

```yaml
kustomize.buildOptions: "--enable-helm --load-restrictor=LoadRestrictionsNone"
```

- `--enable-helm` renders the `helmCharts:` blocks that most directories use to pull upstream charts inline.
- `--load-restrictor=LoadRestrictionsNone` lets a kustomization read files outside its own directory - needed for `helmGlobals.chartHome: ../../../charts` in `gitops/apps/{mealie,media-stack,portfolio,uptime-kuma}` pointing at [`/charts/`](../../charts/).

## Secrets

Runtime secrets come from 1Password via [External Secrets](https://external-secrets.io/). Manifests hold `ExternalSecret` CRs; no ciphertext is committed.

- [`gitops/infrastructure/external-secrets/cluster-secret-store.yaml`](../../gitops/infrastructure/external-secrets/cluster-secret-store.yaml) defines the `onepassword` `ClusterSecretStore` (provider `onepasswordSDK`, 1-hour refresh, 5m cache).
- It authenticates with the `onepassword-credentials` Secret in the `external-secrets` namespace, which [`bootstrap/install.sh`](../bootstrap/install.sh) creates from `op read` before ArgoCD is installed. ESO cannot reconcile without it.
- Add a secret by writing an `ExternalSecret` next to the workload that consumes it, e.g. [`gitops/apps/n8n/n8n-external-secrets.yaml`](../../gitops/apps/n8n/n8n-external-secrets.yaml).

### SOPS (fallback, not wired)

[`/.sops.yaml`](../../.sops.yaml) and the `argocd-sops-age` Secret still exist, but **nothing decrypts `.enc.yaml` today** - the `kustomize-sops` CMP sidecar was removed from the repo-server. The only remaining `.enc.yaml` is an example under `gitops/exprimental/`. Don't add new ones without re-adding the sidecar first.

To re-enable: add the `viaductoss/ksops` CMP sidecar to `repoServer.extraContainers` in `argocd-values.yaml`, mount the `argocd-sops-age` Secret at `SOPS_AGE_KEY_FILE`, and set `plugin.name: kustomize-sops` on the ApplicationSet templates. Repo config that is already in place:

- `path_regex: ^(gitops|charts|manifests)/.*\.enc\.ya?ml$` - only `.enc.yaml` files match; a stray `.yaml` won't be silently encrypted.
- `encrypted_regex: ^(data|stringData)$` - only Secret payloads are encrypted; metadata stays diff-friendly.
- `age:` public key. Private half lives at `~/.config/sops/age/keys.txt` and as the in-cluster `argocd-sops-age` Secret.

## Gateway + cert-manager

All in [`gitops/infrastructure/gateway/`](../../gitops/infrastructure/gateway/):

- `gatewayclass.yaml` - `cilium` GatewayClass.
- `gateway-internal.yaml` - `internal` Gateway (10.10.20.2). Listeners: `http:80`, `https:443`, and `https-internal:443` scoped to `*.internal.nulcell.com`. Fronts cloudflared origins and the admin UIs.
- `gateway-external.yaml` - `external` Gateway (10.10.20.6). Listeners: `http:80`, `https:443`. LAN/Tailscale-only apps that are never published (media-stack).
- `http-redirect.yaml` - shared HTTP→HTTPS redirect attached to both Gateways.
- `clusterissuer.yaml` - `letsencrypt-nulcell-com` ClusterIssuer, DNS-01 against Cloudflare. Swap to `acme-staging-v02` while debugging.
- `wildcard-certificate.yaml` - Certificate for `nulcell.com`, `*.nulcell.com` and `*.internal.nulcell.com`, producing `wildcard-nulcell-tls`. Both Gateways reference it.
- `cloudflare-external-secret.yaml` - pulls the scoped Cloudflare API token (Zone→DNS→Edit on `nulcell.com`) from 1Password.

Both Gateways allow routes `from: All`. HTTPRoutes for infrastructure UIs live in [`gitops/infrastructure/infra-app-httproutes/`](../../gitops/infrastructure/infra-app-httproutes/); app routes live with their app.

external-dns watches `gateway-httproute` + `ingress` sources and syncs every HTTPRoute hostname into Cloudflare, tagged with `txtOwnerId: homecloud`.

## Operating

- **Add an app**: drop `gitops/apps/<name>/kustomization.yaml` (+ resources), commit, push. AppSet picks it up.
- **Remove an app**: delete the directory. `prune: true` + the resources finalizer clean up the cluster.
- **Park something without deleting it**: move it under `gitops/exprimental/` - no ApplicationSet reads that tree.
- **Pause reconcile while debugging**: set `selfHeal: false` on the Application. For a full cluster freeze (e.g. a physical move), see [`gitops/root/safe-scaledown.md`](../../gitops/root/safe-scaledown.md).
- **Stuck Terminating**: `kubectl patch <kind> <name> -p '{"metadata":{"finalizers":[]}}' --type=merge`.

## References

- [ArgoCD docs](https://argo-cd.readthedocs.io/) · [ApplicationSet generators](https://argo-cd.readthedocs.io/en/stable/operator-manual/applicationset/Generators/)
- [Cilium Gateway API](https://docs.cilium.io/en/stable/network/servicemesh/gateway-api/gateway-api/)
- [External Secrets](https://external-secrets.io/) · [1Password provider](https://external-secrets.io/latest/provider/1password-sdk/)
- [SOPS](https://github.com/getsops/sops) · [ksops](https://github.com/viaduct-ai/kustomize-sops)
