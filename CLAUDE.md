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
- **Storage**: Longhorn (replicated block, replica 2 so a node drain never blocks). Backups to S3 (`nulcell-homecloud-backup`, `eu-central-1`) are opt-in per PVC via the `backup` recurring-job group; Postgres (gatus, mealie, n8n, authentik) also archives WAL and takes base backups through the CNPG barman-cloud plugin. Runbook: [`cluster/docs/backup-restore.md`](cluster/docs/backup-restore.md).
- **Virtualization**: KubeVirt (VMs as Kubernetes resources).
- **GitOps**: ArgoCD reads this repo. Five ApplicationSets fan out one Application per directory under [`gitops/infrastructure/*`](gitops/infrastructure/) (wave `0`), [`gitops/operators/*`](gitops/operators/) (wave `5`), [`gitops/security/*`](gitops/security/) (wave `10`), [`gitops/services/*`](gitops/services/) (wave `15`), and [`gitops/apps/*`](gitops/apps/) (wave `100`).
- **Certs**: cert-manager + Cloudflare DNS-01, one `*.nulcell.com` / `*.internal.nulcell.com` wildcard shared by both Gateways.
- **Secrets**: External Secrets Operator against a 1Password `ClusterSecretStore` named `onepassword`. Manifests hold `ExternalSecret` CRs, never ciphertext. The one exception: ESO's own 1Password credential, SOPS + age encrypted at `cluster/bootstrap/onepassword-credentials.sops.yaml` ([`.sops.yaml`](.sops.yaml)) and decrypted by the helmfile hook. ArgoCD decrypts nothing.
- **Security**: Falco (+ Falcosidekick, Falco Talon) for runtime detection and response; Trivy Operator for continuous vulnerability/config scanning, browsable in Headlamp. Kyverno is planned ([`gitops/security/README.md`](gitops/security/README.md)).
- **Observability**: kube-prometheus-stack (metrics, Alertmanager, Grafana); Loki + Grafana Alloy (pod logs). Fluent Bit exists only in the falco stack, shipping kube-apiserver audit logs.
- **Remote access**: Tailscale operator; Cloudflare Tunnel (`cloudflared`) for anything public.
- **Version bumps**: Renovate, every 4h via [`.github/workflows/renovate.yml`](.github/workflows/renovate.yml); one PR per gitops dir, low-risk updates automerge once `Validate` passes.
- **CI**: [`.github/workflows/validate.yml`](.github/workflows/validate.yml) runs `scripts/validate.sh` (kustomize build + kubeconform) on changed gitops dirs.
- **Tasks**: `mise tasks` - `render`, `validate`, `bootstrap`, `talos:upgrade <node-ip>`, `talos:upgrade-k8s`, `restore <ns>/<pvc>`, `cluster:shutdown`, `cluster:start`, `argo:sync`. `restore`, `cluster:shutdown` and `cluster:start` are subcommands of [`scripts/cluster.sh`](scripts/cluster.sh). Talos versions/schematic live in `.mise.toml` `[env]`.
- **Domain**: `nulcell.com`.

Deep reference: [`cluster/README.md`](cluster/README.md). Bootstrap: [`cluster/docs/bootstrap.md`](cluster/docs/bootstrap.md). ArgoCD + secrets: [`cluster/docs/argocd.md`](cluster/docs/argocd.md). Backups and restores: [`cluster/docs/backup-restore.md`](cluster/docs/backup-restore.md). Shutdown: [`cluster/docs/shutdown.md`](cluster/docs/shutdown.md). Talos commands: [`cluster/talos/README.md`](cluster/talos/README.md). What runs in each layer: the [README](README.md#whats-running).

## Directory map

| Path                                               | Contents                                                                                                                                                                        |
| -------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| [`cluster/bootstrap/`](cluster/bootstrap/)         | `helmfile.yaml` (Gateway API CRDs, Cilium, ArgoCD, root app), their values, `namespaces.yaml`, SOPS-encrypted 1Password credential.                                             |
| [`cluster/talos/`](cluster/talos/)                 | Machine-config patches. `generated/` and `secrets/` are gitignored.                                                                                                             |
| [`cluster/docs/`](cluster/docs/)                   | `bootstrap.md`, `argocd.md`, `backup-restore.md`, `shutdown.md`, `terraform.md` (planned Terraform + Terragrunt).                                                               |
| [`gitops/root/`](gitops/root/)                     | Root Application + five ApplicationSets (`infrastructure`, `operators`, `security`, `services`, `apps`) ordered by sync wave.                                                   |
| [`gitops/infrastructure/`](gitops/infrastructure/) | Base platform - every other layer can assume these are up (`secrets` holds the cross-namespace ClusterExternalSecrets: registry pull creds, S3 backup creds).                   |
| [`gitops/operators/`](gitops/operators/)           | Operators installing the CRDs the upper layers consume.                                                                                                                         |
| [`gitops/security/`](gitops/security/)             | Runtime detection and response (falco, falco-talon) and posture scanning (trivy-operator).                                                                                      |
| [`gitops/services/`](gitops/services/)             | Platform services on top of operators (KubeVirt + CDI CRs).                                                                                                                     |
| [`gitops/apps/`](gitops/apps/)                     | Workloads.                                                                                                                                                                      |
| [`gitops/experimental/`](gitops/experimental/)     | Staging area mirroring the layers, not referenced by any ApplicationSet - candidates for promotion or retirement, plus the `apps/restore-test` and `apps/pitr-test` drill apps. |
| [`manifests/`](manifests/)                         | Ad-hoc / one-shot manifests applied manually - NOT reconciled by ArgoCD.                                                                                                        |
| [`scripts/`](scripts/)                             | `validate.sh` (`mise run validate`, CI) and `cluster.sh` (restore, shutdown, start); `transcode-media.sh` is a standalone media utility.                                        |
| [`network/netboot/`](network/netboot/)             | netboot.xyz + ProxyDHCP install notes for the planned provisioning host. Not deployed.                                                                                          |
| [`.github/`](.github/)                             | Renovate + Validate workflows, self-hosted Renovate global config.                                                                                                              |
| [`renovate.json5`](renovate.json5)                 | Repo-level Renovate config (grouping, scheduling, managers).                                                                                                                    |
| [`.mise.toml`](.mise.toml)                         | Pinned local CLIs (`mise install`), `[env]` Talos versions, `[tasks]`.                                                                                                          |
| [`.sops.yaml`](.sops.yaml)                         | SOPS encryption policy. Used for the bootstrap credential only - not wired into ArgoCD.                                                                                         |

## Conventions

- **Never `kubectl apply` from this repo.** ArgoCD owns reconciliation for everything under `gitops/`. Validate with `helm template`, `helm lint`, or `kubectl diff -f`. The user applies anything manual themselves.
- **New workloads**: use `app-template` from `oci://ghcr.io/nulcell/charts`, pinned inline in `kustomization.yaml` (`repo:` + `version:`) so Renovate's kustomize manager tracks the bump. Workloads, routes, secrets and databases (`datastores`: CNPG, Redis) all go in `values.yaml`; image tags there (`image: {repository, tag}`) are tracked by Renovate too. Use an upstream chart only for apps that ship their own CRDs or lifecycle logic (`authentik`). Chart source and changes live in [`nulcell/charts`](https://github.com/nulcell/charts); bump every app pinning it together. The `apps` ApplicationSet picks up the directory on the next reconcile.
- **Ad-hoc / one-shot manifests** go in [`manifests/`](manifests/) and are applied manually.
- **Helm chart values**: prefer Gateway API `HTTPRoute` over Ingress; `storageClassName: longhorn`; security context `runAsNonRoot: true` with explicit `runAsUser`/`runAsGroup`; always set both `resources.requests` and `resources.limits`.
- **Images**: always name the registry (`docker.io/library/redis`, not `redis`; `docker.io/n8nio/n8n`, not `n8nio/n8n`). `scripts/validate.sh` fails on any rendered container image without one, so override upstream chart defaults that omit it.
- **Gateways** (both in the `gateway` namespace, both L2-announced on the LAN, both terminating the same wildcard cert):
  - `external` (10.10.20.6) - LAN/Tailscale-only apps that are never published. Bind the plain hostname (`jellyfin.nulcell.com`); external-dns points the Cloudflare record at the private IP, so it only resolves usefully from inside.
  - `internal` (10.10.20.2) - cloudflared origins plus in-cluster admin UIs (`argocd`, `grafana`, `longhorn`, `headlamp`, `falcosidekick`).
- **Publishing an app to the internet**: apps never bind a public hostname directly. Give the `HTTPRoute` an origin hostname on the `internal` Gateway's `https-internal` listener (`<app>.internal.nulcell.com`, covered by the wildcard cert), then add the public hostname in [`gitops/apps/cloudflared/values.yaml`](gitops/apps/cloudflared/values.yaml) in two places: `ingress` in the tunnel config (with `originRequest.httpHostHeader` set to that origin hostname) and a `register-*` init container in `dns-registration` (the DNS job registers the tunnel record per hostname; the image has no shell). Cloudflare terminates public TLS. An app with no admin UI of its own may skip the HTTPRoute and point `service:` straight at its ClusterIP Service (`mealie` does this).
- **Talos changes** go through [`cluster/talos/patches/`](cluster/talos/patches/) - never edit `generated/` directly. System extensions (iscsi-tools, util-linux-tools, microcode, amdgpu) bake into the image at install time; adding them later needs an OS upgrade - flag this on any change.
- **Secrets**: add an `ExternalSecret` referencing the `onepassword` `ClusterSecretStore`; never commit ciphertext or a raw token (sole exception: the SOPS bootstrap credential). `.env` files are generated locally from `.env.example` via `op inject` and gitignored. Don't add SOPS files under `gitops/` - nothing decrypts them.
- **PVC backups are opt-in** (they cost money): label a stateful PVC `recurring-job.longhorn.io/source: enabled` and `recurring-job-group.longhorn.io/backup: enabled`. Bulk media (`media-stack-data`), Prometheus and Postgres PVCs are never labeled: Postgres is backed up by the CNPG barman plugin only (base backups + WAL).
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
