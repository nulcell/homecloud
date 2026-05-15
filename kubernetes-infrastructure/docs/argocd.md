# ArgoCD Reference

Everything ArgoCD needs to drive this cluster from the [`gitops/`](../gitops/) folder: app-of-apps layout, SOPS wiring, sync-wave conventions, and worked examples.

The cluster bootstrap in [bootstrap.md](bootstrap.md) ends with ArgoCD installed and a single `root` Application pointed at `gitops/root/`. This doc picks up from there.

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
│   ├── root-app.yaml                  # the Application applied by hand during bootstrap
│   ├── infrastructure-appset.yaml     # ApplicationSet → one App per infrastructure/ subdir
│   └── apps-appset.yaml               # ApplicationSet → one App per apps/ subdir
├── infrastructure/
│   ├── kubevirt/
│   │   ├── kustomization.yaml
│   │   ├── operator.yaml              # KubeVirt operator manifest
│   │   └── kubevirt-cr.yaml           # KubeVirt CR (feature gates, etc.)
│   ├── kube-prometheus-stack/
│   │   ├── kustomization.yaml         # uses --enable-helm to render the chart
│   │   └── values.yaml
│   ├── gateway/
│   │   ├── gatewayclass.yaml          # CiliumGatewayClass
│   │   ├── gateway-default.yaml       # default Gateway listening on the L2-LB IP
│   │   └── clusterissuer.yaml         # cert-manager ClusterIssuer (Let's Encrypt or self-signed)
│   └── sops-secrets/
│       └── example-secret.enc.yaml    # demo encrypted secret
└── apps/
    └── (your workloads, added later)
```

> Every directory under `infrastructure/` and `apps/` is expected to contain a `kustomization.yaml`. The ApplicationSets use a directory generator and discover them automatically.

---

## The root Application

Already applied during bootstrap (step 11). For reference:

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
    directory:
      recurse: false                    # only pick up the ApplicationSets in this dir
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

---

## ApplicationSets

Two sets, one per top-level GitOps folder. Splitting them lets you put cluster-critical infra on stricter sync settings than workloads.

```yaml
# gitops/root/infrastructure-appset.yaml
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet
metadata:
  name: infrastructure
  namespace: argocd
spec:
  generators:
    - git:
        repoURL: https://github.com/<you>/homecloud
        revision: main
        directories:
          - path: kubernetes-infrastructure/gitops/infrastructure/*
  template:
    metadata:
      name: 'infra-{{path.basename}}'
      annotations:
        argocd.argoproj.io/sync-wave: "0"
    spec:
      project: default
      source:
        repoURL: https://github.com/<you>/homecloud
        targetRevision: main
        path: '{{path}}'
        plugin:
          name: kustomize-sops
      destination:
        server: https://kubernetes.default.svc
        namespace: '{{path.basename}}'
      syncPolicy:
        automated:
          prune: true
          selfHeal: true
        syncOptions:
          - CreateNamespace=true
          - ServerSideApply=true
```

```yaml
# gitops/root/apps-appset.yaml
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet
metadata:
  name: apps
  namespace: argocd
spec:
  generators:
    - git:
        repoURL: https://github.com/<you>/homecloud
        revision: main
        directories:
          - path: kubernetes-infrastructure/gitops/apps/*
  template:
    metadata:
      name: 'app-{{path.basename}}'
      annotations:
        argocd.argoproj.io/sync-wave: "10"   # always after infrastructure
    spec:
      project: default
      source:
        repoURL: https://github.com/<you>/homecloud
        targetRevision: main
        path: '{{path}}'
        plugin:
          name: kustomize-sops
      destination:
        server: https://kubernetes.default.svc
        namespace: '{{path.basename}}'
      syncPolicy:
        automated:
          prune: true
          selfHeal: true
        syncOptions:
          - CreateNamespace=true
          - ServerSideApply=true
```

### Sync waves

Within an app's manifests, set `argocd.argoproj.io/sync-wave` annotations to order resources when initial creation matters (CRDs before CRs, ClusterIssuer before Certificates, etc.):

| Wave  | Typical content                                                          |
| ----- | ------------------------------------------------------------------------ |
| `-10` | CRDs                                                                     |
| `-5`  | Namespaces, RBAC                                                         |
| `0`   | Operators / controllers                                                  |
| `5`   | Custom Resources for those operators (KubeVirt CR, Certificate, Gateway) |
| `10`  | Workloads                                                                |

---

## SOPS with kustomize-sops

ArgoCD's repo-server runs `kustomize build` — to make it transparently decrypt SOPS-encrypted secrets, register a Config Management Plugin (CMP).

### 1. Repo-level config

```yaml
# .sops.yaml  (at the repo root, NOT inside kubernetes-infrastructure/)
creation_rules:
  - path_regex: kubernetes-infrastructure/.*\.enc\.ya?ml$
    encrypted_regex: ^(data|stringData)$
    age: <YOUR_AGE_PUBLIC_KEY>
```

Encrypt a secret in-place:

```bash
sops --encrypt --in-place gitops/infrastructure/sops-secrets/example-secret.enc.yaml
```

`.sops.yaml` makes the `--encrypt` invocation pick the right key and only encrypt the `data`/`stringData` fields, so the rest of the manifest stays readable in git diffs.

### 2. CMP sidecar on the repo-server

Add a CMP sidecar to the ArgoCD repo-server. Patch `bootstrap/argocd-values.yaml`:

```yaml
repoServer:
  extraContainers:
    - name: kustomize-sops
      image: viaductoss/ksops:v4.3.3       # bundles kustomize + sops
      command: [/var/run/argocd/argocd-cmp-server]
      env:
        - name: SOPS_AGE_KEY_FILE
          value: /sops/key.txt
      volumeMounts:
        - name: var-files
          mountPath: /var/run/argocd
        - name: plugins
          mountPath: /home/argocd/cmp-server/plugins
        - name: cmp-tmp
          mountPath: /tmp
        - name: cmp-config
          mountPath: /home/argocd/cmp-server/config/plugin.yaml
          subPath: plugin.yaml
        - name: sops-age
          mountPath: /sops
          readOnly: true
  volumes:
    - name: cmp-tmp
      emptyDir: {}
    - name: cmp-config
      configMap:
        name: argocd-cmp-kustomize-sops

configs:
  cmp:
    create: true
    plugins:
      kustomize-sops:
        generate:
          command: [sh, -c]
          args: ["kustomize build --enable-alpha-plugins --enable-exec ."]
```

The `plugin.name: kustomize-sops` in each ApplicationSet template (above) tells ArgoCD to use this plugin when rendering manifests.

### 3. Example encrypted secret

```yaml
# gitops/infrastructure/sops-secrets/example-secret.enc.yaml   (BEFORE encryption)
apiVersion: v1
kind: Secret
metadata:
  name: example
  namespace: default
type: Opaque
stringData:
  username: admin
  password: super-secret-value
```

After `sops --encrypt --in-place`, the `stringData` block is encrypted but the manifest is still a valid k8s resource — ArgoCD will decrypt it on render and apply the plaintext to the cluster.

---

## Cilium Gateway example

```yaml
# gitops/infrastructure/gateway/gatewayclass.yaml
apiVersion: gateway.networking.k8s.io/v1
kind: GatewayClass
metadata:
  name: cilium
spec:
  controllerName: io.cilium/gateway-controller
```

```yaml
# gitops/infrastructure/gateway/gateway-default.yaml
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: default
  namespace: gateway
spec:
  gatewayClassName: cilium
  listeners:
    - name: http
      protocol: HTTP
      port: 80
      allowedRoutes:
        namespaces:
          from: All
    - name: https
      protocol: HTTPS
      port: 443
      tls:
        mode: Terminate
        certificateRefs:
          - kind: Secret
            name: wildcard-home-lab-tls
      allowedRoutes:
        namespaces:
          from: All
```

```yaml
# example HTTPRoute used by ArgoCD itself (lives in gitops/infrastructure/argocd/ or similar)
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: argocd
  namespace: argocd
spec:
  parentRefs:
    - name: default
      namespace: gateway
  hostnames: [argocd.home.lab]
  rules:
    - matches:
        - path:
            type: PathPrefix
            value: /
      backendRefs:
        - name: argocd-server
          port: 80
```

The Gateway picks an IP from the Cilium `CiliumLoadBalancerIPPool` you created during bootstrap.

---

## Self-managing ArgoCD

Once everything is stable, you can migrate ArgoCD's own config under GitOps so even ArgoCD upgrades are declarative:

1. Create `gitops/infrastructure/argocd/` with a kustomization that renders the same Helm chart and values as in `bootstrap/argocd-values.yaml`.
2. Apply once to make ArgoCD adopt its own Application.
3. From then on, ArgoCD reconciles itself.

This is optional and recommended only after you trust the rest of the pipeline — a bad sync that breaks ArgoCD is annoying to recover from. The same caveat applies to Cilium and Longhorn; the safer pattern is to leave the **install** under Helm and put **values changes** under GitOps once the cluster is mature.

---

## What ArgoCD should manage (vs. not)

| Component                           | Owner                    | Why                                                        |
| ----------------------------------- | ------------------------ | ---------------------------------------------------------- |
| Talos OS, machine config, etc.      | `talosctl` (out of band) | Image-level; can't sensibly live in K8s                    |
| Cilium install                      | Helm (bootstrap)         | Cluster network — too dangerous to sync from git initially |
| Longhorn install                    | Helm (bootstrap)         | Storage — same reasoning as Cilium                         |
| ArgoCD install                      | Helm (bootstrap)         | Chicken-and-egg until self-management is set up            |
| Cilium L2 IP pool / policy          | ArgoCD                   | Pure manifests, low risk                                   |
| Gateway API CRDs                    | Helm (bootstrap)         | Need them before Cilium starts                             |
| Gateway / HTTPRoute / ClusterIssuer | ArgoCD                   |                                                            |
| cert-manager install                | Helm (bootstrap)         | Required by KubeVirt webhooks                              |
| cert-manager Issuers/Certificates   | ArgoCD                   |                                                            |
| KubeVirt operator + CR              | ArgoCD                   |                                                            |
| metrics-server                      | ArgoCD                   | Replace the helm-installed copy when ready                 |
| kube-prometheus-stack               | ArgoCD                   |                                                            |
| Application workloads               | ArgoCD                   |                                                            |
| Secrets (encrypted)                 | ArgoCD via SOPS          |                                                            |

The split favors safety in the bootstrap and GitOps for everything that follows.

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
