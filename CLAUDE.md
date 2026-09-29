# HomeCloud - Agent Instructions

Keep this file accurate. If a task changes architecture, structure, naming, tooling, or workflow, update this file in the same change.

## Commandments

Non-negotiable, for every file in this repo:

1. Minimal code - the smallest change that does the job.
2. Simplicity over complexity - no speculative abstraction, options, or config.
3. Comments only when necessary, and concise - state constraints, not mechanics.
4. Low verbosity everywhere: code, config, docs, and agent output.

## Stack

Self-hosted private cloud on bare metal. Two nodes today (1 control plane with scheduling on, 1 worker), designed to scale to a 3-node HA control plane.

- **OS**: Talos Linux. Machine-config patches in [`cluster/talos/patches/`](cluster/talos/patches/); image schematic baked at Talos Image Factory with `iscsi-tools`, `util-linux-tools`, microcode, optional `amdgpu`.
- **Cluster**: Kubernetes via Talos. Cilium + ArgoCD bootstrapped by helmfile ([`cluster/bootstrap/helmfile.yaml`](cluster/bootstrap/helmfile.yaml), `mise run bootstrap`); everything else via GitOps.
- **CNI / LB / Gateway**: Cilium (kube-proxy replacement, Gateway API, L2 announcements). No MetalLB.
- **Storage**: Longhorn (replicated block).
- **Virtualization**: KubeVirt (VMs as Kubernetes resources).
- **GitOps**: ArgoCD reads this repo. Five ApplicationSets fan out one Application per directory under [`gitops/infrastructure/*`](gitops/infrastructure/) (wave `0`), [`gitops/operators/*`](gitops/operators/) (wave `5`), [`gitops/security/*`](gitops/security/) (wave `10`), [`gitops/services/*`](gitops/services/) (wave `15`), and [`gitops/apps/*`](gitops/apps/) (wave `100`).
- **Certs**: cert-manager + Cloudflare DNS-01, one `*.nulcell.com` / `*.internal.nulcell.com` wildcard shared by both Gateways.
- **Secrets**: External Secrets Operator against a 1Password `ClusterSecretStore` named `onepassword`. Manifests hold `ExternalSecret` CRs, never ciphertext. The one exception: ESO's own 1Password credential, SOPS + age encrypted at `cluster/bootstrap/onepassword-credentials.sops.yaml` ([`.sops.yaml`](.sops.yaml)) and decrypted by the helmfile hook. ArgoCD decrypts nothing.
- **Observability**: kube-prometheus-stack (metrics, Alertmanager, Grafana); Loki + Grafana Alloy (pod logs). Fluent Bit exists only in the falco stack, shipping kube-apiserver audit logs.
- **Remote access**: Tailscale operator; Cloudflare Tunnel (`cloudflared`) for anything public.
- **Version bumps**: Renovate, every 4h via [`.github/workflows/renovate.yml`](.github/workflows/renovate.yml); one PR per gitops dir, low-risk updates automerge once `Validate` passes.
- **CI**: [`.github/workflows/validate.yml`](.github/workflows/validate.yml) runs `scripts/validate.sh` (kustomize build + kubeconform) on changed gitops dirs.
- **Tasks**: `mise tasks` - `render`, `validate`, `bootstrap`, `preflight`, `talos:upgrade`, `talos:config`, `talos:upgrade-k8s`, `restore`, `cluster:shutdown`, `cluster:start`, `argo:sync`. Node/storage lifecycle tasks are subcommands of [`scripts/cluster.sh`](scripts/cluster.sh); nodes are discovered from the cluster, never hard-coded. Talos versions/schematic live in `.mise.toml` `[env]`.
- **Domain**: `nulcell.com`.

Deep reference: [`cluster/README.md`](cluster/README.md). Bootstrap steps: [`cluster/docs/bootstrap.md`](cluster/docs/bootstrap.md). ArgoCD layout + secrets: [`cluster/docs/argocd.md`](cluster/docs/argocd.md). Talos commands: [`cluster/talos/README.md`](cluster/talos/README.md).

## Directory map

| Path                                               | Contents                                                                                                                                                                                                                       |
| -------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| [`cluster/bootstrap/`](cluster/bootstrap/)         | `helmfile.yaml` (Gateway API CRDs, Cilium, ArgoCD, root app), their values, `namespaces.yaml`, SOPS-encrypted 1Password credential.                                                                                             |
| [`cluster/talos/`](cluster/talos/)                 | Machine-config patches. `generated/` and `secrets/` are gitignored.                                                                                                                                                            |
| [`cluster/docs/`](cluster/docs/)                   | `bootstrap.md`, `argocd.md`, `terraform.md` (planned Terraform + Terragrunt).                                                                                                                                                  |
| [`gitops/root/`](gitops/root/)                     | Root Application + five ApplicationSets (`infrastructure`, `operators`, `security`, `services`, `apps`) ordered by sync wave.                                                                                                  |
| [`gitops/infrastructure/`](gitops/infrastructure/) | Base platform - every other layer can assume these are up: cert-manager, external-dns, external-secrets, gateway, headlamp, infra-app-httproutes, keda, kube-prometheus-stack, loki, longhorn, metrics-server, registry-credentials, reloader. |
| [`gitops/operators/`](gitops/operators/)           | Operators installing CRDs the upper layers consume: cnpg, falco, kubevirt, mariadb, tailscale.                                                                                                                                 |
| [`gitops/security/`](gitops/security/)             | Security stack - falco (runtime detection via falco-operator CRs + falco-talon response actions).                                                                                                                              |
| [`gitops/services/`](gitops/services/)             | Platform services on top of operators: kubevirt.                                                                                                                                                                               |
| [`gitops/apps/`](gitops/apps/)                     | Workloads (`actual-budget`, `authentik`, `cloudflared`, `gatus`, `mealie`, `media-stack`, `n8n`, `portfolio`).                                                                                                                 |
| [`gitops/experimental/`](gitops/experimental/)       | Staging area, not referenced by any ApplicationSet - candidates for promotion or retirement.                                                                                                                                   |
| [`manifests/`](manifests/)                         | Ad-hoc / one-shot manifests applied manually - NOT reconciled by ArgoCD.                                                                                                                                                       |
| [`scripts/`](scripts/)                             | Standalone operator utilities; `validate.sh` backs `mise run validate` and CI, `cluster.sh` backs the node/storage lifecycle tasks.                                                                                                                                               |
| [`network/netboot/`](network/netboot/)             | netboot.xyz + ProxyDHCP install notes for the planned provisioning host. Not deployed.                                                                                                                                         |
| [`.github/`](.github/)                             | Renovate + Validate workflows, self-hosted Renovate global config.                                                                                                                                                             |
| [`renovate.json5`](renovate.json5)                 | Repo-level Renovate config (grouping, scheduling, managers).                                                                                                                                                                   |
| [`.mise.toml`](.mise.toml)                         | Pinned local CLIs (`mise install`), `[env]` Talos versions, `[tasks]`.                                                                                                                                                         |
| [`.sops.yaml`](.sops.yaml)                         | SOPS encryption policy. Used for the bootstrap credential only - not wired into ArgoCD.                                                                                                                                        |

## Conventions

- **Never `kubectl apply` from this repo.** ArgoCD owns reconciliation for everything under `gitops/`. Validate with `helm template`, `helm lint`, or `kubectl diff -f`. The user applies anything manual themselves.
- **New workloads**: default to a maintained upstream chart pinned inline in `kustomization.yaml` (`repo:` + `version:`), so Renovate's kustomize manager tracks the bump - this is what `actual-budget`, `authentik`, `cloudflared` and `n8n` do. When no upstream chart fits, use `app-template` from `oci://ghcr.io/nulcell/charts` the same way - `gatus`, `mealie`, `media-stack` and `portfolio` do. Chart source and changes live in [`nulcell/charts`](https://github.com/nulcell/charts); bump every app pinning it together. Either way the `apps` ApplicationSet picks up the directory on the next reconcile.
- **Ad-hoc / one-shot manifests** go in [`manifests/`](manifests/) and are applied manually.
- **Helm chart values**: prefer Gateway API `HTTPRoute` over Ingress; `storageClassName: longhorn`; security context `runAsNonRoot: true` with explicit `runAsUser`/`runAsGroup`; always set both `resources.requests` and `resources.limits`.
- **Gateways** (both in the `gateway` namespace, both L2-announced on the LAN, both terminating the same wildcard cert):
  - `external` (10.10.20.6) - LAN/Tailscale-only apps that are never published. Bind the plain hostname (`jellyfin.nulcell.com`); external-dns points the Cloudflare record at the private IP, so it only resolves usefully from inside.
  - `internal` (10.10.20.2) - cloudflared origins plus in-cluster admin UIs (`argocd`, `grafana`, `longhorn`, `headlamp`, `falcosidekick`).
- **Publishing an app to the internet**: apps never bind a public hostname directly. Give the `HTTPRoute` an origin hostname on the `internal` Gateway's `https-internal` listener (`<app>.internal.nulcell.com`, covered by the wildcard cert), then add the public hostname to `ingress` in [`gitops/apps/cloudflared/values.yaml`](gitops/apps/cloudflared/values.yaml) with `originRequest.httpHostHeader` set to that origin hostname. Cloudflare terminates public TLS; the PostSync job in that chart registers the tunnel DNS record for every `hostname` in the list. An app with no admin UI of its own may skip the HTTPRoute and point `service:` straight at its ClusterIP Service (`mealie` does this).
- **Talos changes** go through [`cluster/talos/patches/`](cluster/talos/patches/) - never edit `generated/` directly. System extensions (iscsi-tools, util-linux-tools, microcode, amdgpu) bake into the image at install time; adding them later needs an OS upgrade - flag this on any change.
- **Secrets**: add an `ExternalSecret` referencing the `onepassword` `ClusterSecretStore`; never commit ciphertext or a raw token (sole exception: the SOPS bootstrap credential). `.env` files are generated locally from `.env.example` via `op inject` and gitignored. Don't add SOPS files under `gitops/` - nothing decrypts them.
- **Shell scripts** target Ubuntu 24.04 LTS unless otherwise noted; idempotent where possible.

## Common commands

```bash
mise run render gitops/apps/<app>   # render without applying
mise run validate [dirs...]         # render + kubeconform (all live dirs by default)
```

Talos workflow lives in [`cluster/talos/README.md`](cluster/talos/README.md).

## Roadmap notes

- **HA**: 1 → 3 control planes directly; two-node etcd is worse than single-node.
- **Policy engine**: Kyverno (not OPA Gatekeeper) - YAML policies instead of Rego, native `PolicyReport` CRDs for Policy Reporter, and mutate/generate rules. Not deployed yet; see [`gitops/security/README.md`](gitops/security/README.md).
- **Terraform + Terragrunt**: planned for Talos config + bootstrap - see [`cluster/docs/terraform.md`](cluster/docs/terraform.md).
- **Bare-metal provisioning**: in planning - Pi-hole (DNS + DHCP) + netboot + Tailscale on a Raspberry Pi. The old MaaS install script is gone; see [`network/netboot/`](network/netboot/).
