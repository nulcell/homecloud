# ArgoCD

Everything ArgoCD owns after [bootstrap](bootstrap.md): app-of-apps layout, SOPS wiring, sync ordering.

## Mental model

```
bootstrap (Helm)
   │
   ▼
ArgoCD ──watches──► gitops/root/   (root Application, directory.recurse=false)
                          │
                          └── ApplicationSets fan out into one Application per directory under:
                                • gitops/infrastructure/*    (cert-manager, longhorn, kubevirt, gateway, ...)
                                • gitops/apps/*              (workloads)
```

Source of truth = this repo. The only cluster state ArgoCD owns that isn't in git: the age private key (`argocd-sops-age` Secret) and the rotated admin password.

## Layout

```
gitops/
├── root/
│   ├── root-app.yaml               # applied once by bootstrap/install.sh
│   ├── infrastructure-appset.yaml  # one App per gitops/infrastructure/* dir
│   └── apps-appset.yaml            # one App per gitops/apps/* dir
├── infrastructure/                 # cert-manager, longhorn, metrics-server,
│   │                               # cnpg, kube-prometheus-stack, kubevirt,
│   │                               # gateway, external-dns, infra-app-httproutes,
│   │                               # sops-secrets
│   └── …
└── apps/                           # media-stack, n8n
```

Every directory under `infrastructure/` and `apps/` must contain a `kustomization.yaml` — the ApplicationSets pick them up automatically.

## Sync waves

`argocd.argoproj.io/sync-wave` orders resources **within one Application** only. AppSet-generated Applications each reconcile independently.

| Wave  | Typical content                                       |
| ----- | ----------------------------------------------------- |
| `-10` | CRDs                                                  |
| `-5`  | Namespaces, RBAC                                      |
| `0`   | Operators / controllers (default for `infrastructure`)|
| `5`   | Custom Resources for those operators                  |
| `10`  | Workloads (default for `apps`)                        |

When an Application sync fails because another Application's CRDs aren't there yet, `selfHeal: true` retries every 60s. First bootstrap is noisy for ~1–2 minutes then converges.

## SOPS with kustomize-sops

The repo-server renders manifests via the `kustomize-sops` CMP (a sidecar on the repo-server), which transparently decrypts `*.enc.yaml` files and runs `kustomize build --enable-helm`.

**Repo config** — [`/.sops.yaml`](../../.sops.yaml):

- `path_regex: ^(gitops|charts|manifests)/.*\.enc\.ya?ml$` — only `.enc.yaml` files match; a stray `.yaml` won't be silently encrypted.
- `encrypted_regex: ^(data|stringData)$` — only Secret payloads are encrypted; metadata stays diff-friendly.
- `age:` public key. Private half lives at `~/.config/sops/age/keys.txt` and as the in-cluster `argocd-sops-age` Secret.

Encrypt in place:

```bash
sops --encrypt --in-place gitops/infrastructure/sops-secrets/example-secret.enc.yaml
```

**CMP sidecar** — wired in [`bootstrap/argocd-values.yaml`](../bootstrap/argocd-values.yaml):

- Image `viaductoss/ksops` bundles kustomize + sops + ksops.
- `sops-age` volume mounts the Secret; `SOPS_AGE_KEY_FILE=/sops/key.txt`.
- A `download-tools` initContainer drops `helm` into a shared volume so `kustomize build --enable-helm` can render `helmCharts:` blocks (cnpg, cert-manager, longhorn, …).
- `--load-restrictor=LoadRestrictionsNone` lets a kustomization read files outside its own directory — needed for `helmGlobals.chartHome: ../../../charts` in `gitops/apps/*` pointing at [`/charts/`](../../charts/).

Each ApplicationSet template sets `plugin.name: kustomize-sops` to use this renderer.

## Gateway + cert-manager

All in [`gitops/infrastructure/gateway/`](../../gitops/infrastructure/gateway/):

- `gatewayclass.yaml` — `cilium` GatewayClass.
- `gateway-default.yaml` — `default` Gateway in `gateway` namespace, HTTPS on `:443` against the cert-manager-produced `wildcard-nulcell-tls` Secret. `allowedRoutes.namespaces.from: All`.
- `clusterissuer.yaml` — `letsencrypt-nulcell-com` ClusterIssuer, DNS-01 against Cloudflare. Swap to `acme-staging-v02` while debugging.
- `wildcard-certificate.yaml` — `*.nulcell.com` Certificate producing `wildcard-nulcell-tls`.
- `cloudflare-token.enc.yaml` — SOPS-encrypted Cloudflare API token (scoped Zone→DNS→Edit for `nulcell.com` only).

Per-service HTTPRoutes attach to `default` via `parentRefs` from [`gitops/infrastructure/infra-app-httproutes/`](../../gitops/infrastructure/infra-app-httproutes/).

## Operating

- **Add an app**: drop `gitops/apps/<name>/kustomization.yaml` (+ resources), commit, push. AppSet picks it up.
- **Remove an app**: delete the directory. `prune: true` + the resources finalizer clean up the cluster.
- **Pause reconcile while debugging**: set `selfHeal: false` on the Application, or annotate `argocd.argoproj.io/sync-options: SkipDryRunOnMissingResource=true`.
- **Stuck Terminating**: `kubectl patch <kind> <name> -p '{"metadata":{"finalizers":[]}}' --type=merge`.

## References

- [ArgoCD docs](https://argo-cd.readthedocs.io/) · [ApplicationSet generators](https://argo-cd.readthedocs.io/en/stable/operator-manual/applicationset/Generators/)
- [Cilium Gateway API](https://docs.cilium.io/en/stable/network/servicemesh/gateway-api/gateway-api/)
- [SOPS](https://github.com/getsops/sops) · [ksops](https://github.com/viaduct-ai/kustomize-sops)
