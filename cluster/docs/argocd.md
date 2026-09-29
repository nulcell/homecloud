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

Source of truth = this repo. Cluster state ArgoCD does *not* own: the `onepassword-credentials` Secret applied by the bootstrap helmfile, and the rotated admin password.

## Layout

```
gitops/
├── root/
│   ├── root-app.yaml               # applied once by bootstrap/helmfile.yaml
│   ├── infrastructure-appset.yaml
│   ├── operators-appset.yaml
│   ├── security-appset.yaml
│   ├── services-appset.yaml
│   └── apps-appset.yaml
├── infrastructure/   # cert-manager, external-dns, external-secrets, gateway, headlamp,
│                     # infra-app-httproutes, kube-prometheus-stack, loki, longhorn,
│                     # metrics-server, secrets
├── operators/        # cnpg, falco, kubevirt, mariadb, tailscale
├── security/         # falco
├── services/         # kubevirt (KubeVirt + CDI CRs)
├── apps/             # actual-budget, authentik, cloudflared, gatus, mealie,
│                     # media-stack, n8n, portfolio
└── experimental/      # staging area — no ApplicationSet reads this, nothing here runs
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
- `--load-restrictor=LoadRestrictionsNone` lets a kustomization read files outside its own directory. Nothing needs it since the local charts moved to [`nulcell/charts`](https://github.com/nulcell/charts).

## Secrets

Runtime secrets come from 1Password via [External Secrets](https://external-secrets.io/). Manifests hold `ExternalSecret` CRs; the only committed ciphertext is the SOPS-encrypted bootstrap credential below.

- [`gitops/infrastructure/external-secrets/cluster-secret-store.yaml`](../../gitops/infrastructure/external-secrets/cluster-secret-store.yaml) defines the `onepassword` `ClusterSecretStore` (provider `onepasswordSDK`, 1-hour refresh, 5m cache).
- It authenticates with the `onepassword-credentials` Secret in the `external-secrets` namespace, which [`bootstrap/helmfile.yaml`](../bootstrap/helmfile.yaml) decrypts with SOPS and applies before ArgoCD is installed. ESO cannot reconcile without it.
- Add a secret by writing an `ExternalSecret` next to the workload that consumes it, e.g. [`gitops/apps/authentik/authentik-external-secret.yaml`](../../gitops/apps/authentik/authentik-external-secret.yaml), or an `externalSecrets:` block in an app-template `values.yaml`.

### SOPS (bootstrap only)

[`/.sops.yaml`](../../.sops.yaml) + age encrypt one file: [`bootstrap/onepassword-credentials.sops.yaml`](../bootstrap/), decrypted by the helmfile hook on your machine. ArgoCD decrypts nothing - the ksops CMP sidecar is gone - so don't put SOPS files under `gitops/`.

- `encrypted_regex: ^(data|stringData)$` - only Secret payloads are encrypted; metadata stays diff-friendly.
- `age:` public key. Private half lives at `~/.config/sops/age/keys.txt`; back it up in 1Password.
- To re-wire ArgoCD: add the `viaductoss/ksops` CMP sidecar to `repoServer.extraContainers`, mount an age-key Secret at `SOPS_AGE_KEY_FILE`, and set `plugin.name: kustomize-sops` on the ApplicationSet templates.

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
- **Park something without deleting it**: move it under `gitops/experimental/` - no ApplicationSet reads that tree.
- **Pause every app while debugging**: give the `default` AppProject an always-on deny sync window, which blocks automated sync and self-heal but keeps status updating: `kubectl -n argocd patch appproject default --type merge -p '{"spec":{"syncWindows":[{"kind":"deny","schedule":"* * * * *","duration":"24h","applications":["*"],"namespaces":["*"],"clusters":["*"]}]}}'`; remove it with `-p '{"spec":{"syncWindows":null}}'`. One app: set `selfHeal: false` on it. Full shutdown: [`gitops/root/safe-scaledown.md`](../../gitops/root/safe-scaledown.md).
- **Stuck Terminating**: `kubectl patch <kind> <name> -p '{"metadata":{"finalizers":[]}}' --type=merge`.

## References

- [ArgoCD docs](https://argo-cd.readthedocs.io/) · [ApplicationSet generators](https://argo-cd.readthedocs.io/en/stable/operator-manual/applicationset/Generators/)
- [Cilium Gateway API](https://docs.cilium.io/en/stable/network/servicemesh/gateway-api/gateway-api/)
- [External Secrets](https://external-secrets.io/) · [1Password provider](https://external-secrets.io/latest/provider/1password-sdk/)
- [SOPS](https://github.com/getsops/sops) · [ksops](https://github.com/viaduct-ai/kustomize-sops)
