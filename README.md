# HomeCloud

Self-hosted private cloud on bare metal. Talos + Cilium + ArgoCD + Longhorn + KubeVirt.

Two nodes today (1 control plane with scheduling on, 1 worker), designed to scale to a 3-node HA control plane.

## Layout

| Path                                   | Purpose                                                                                                           |
| -------------------------------------- | ----------------------------------------------------------------------------------------------------------------- |
| [`cluster/`](cluster/)                 | Talos machine configs + imperative bootstrap (Cilium, ArgoCD). Start at [`cluster/README.md`](cluster/README.md). |
| [`gitops/`](gitops/)                   | ArgoCD's source of truth - root, infrastructure, operators, security, services, apps.                             |
| [`manifests/`](manifests/)             | Ad-hoc / one-shot manifests, applied manually. Not reconciled by ArgoCD.                                          |
| [`scripts/`](scripts/)                 | `validate.sh` and `cluster.sh` (restore, shutdown, start), behind the mise tasks.                                 |
| [`network/netboot/`](network/netboot/) | netboot.xyz + ProxyDHCP install notes for the planned provisioning host. Not deployed.                            |
| [`renovate.json5`](renovate.json5)     | Renovate config; runs every 4h via [`.github/workflows/renovate.yml`](.github/workflows/renovate.yml).            |

Conventions for agents and humans: [CLAUDE.md](CLAUDE.md).

## Setup

```bash
brew install mise op
mise install   # everything pinned in .mise.toml
```

`op` (1Password CLI) is the only required tool not managed by mise. It backs the `op://homecloud/...` URIs used in `.env` generation and in re-encrypting the bootstrap credential.

Common tasks live in `.mise.toml` - `mise tasks` lists them (`render`, `validate`, `bootstrap`, `talos:upgrade`, `talos:upgrade-k8s`, `restore`, `cluster:shutdown`, `cluster:start`, `argo:sync`). PRs touching `gitops/` run `mise run validate` in [`.github/workflows/validate.yml`](.github/workflows/validate.yml).

## What's running

Versions live next to the manifests - `gitops/*/*/kustomization.yaml` for chart versions, [`cluster/bootstrap/helmfile.yaml`](cluster/bootstrap/helmfile.yaml) for Cilium / Gateway API / ArgoCD.

| Layer                                              | Deployed                                                                                                                                                           |
| -------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| [`infrastructure/`](gitops/infrastructure/) wave 0 | cert-manager, external-dns, external-secrets, gateway, headlamp, infra-app-httproutes, keda, kube-prometheus-stack, loki, longhorn, metrics-server, reloader, secrets |
| [`operators/`](gitops/operators/) wave 5           | cnpg, falco, kubevirt, mariadb, tailscale                                                                                                                          |
| [`security/`](gitops/security/) wave 10            | falco, trivy                                                                                                                                                       |
| [`services/`](gitops/services/) wave 15            | kubevirt (KubeVirt + CDI CRs)                                                                                                                                      |
| [`apps/`](gitops/apps/) wave 100                   | actual-budget, authentik, cloudflared, gatus, mealie, media-stack, n8n, portfolio                                                                                  |

[`gitops/experimental/`](gitops/experimental/) is a staging area - no ApplicationSet reads it, so nothing in it runs. It mirrors the layers: `apps/` holds homarr, outline, speedtest-tracker, uptime-kuma and the `restore-test` and `pitr-test` drill apps; `infrastructure/` rancher; `operators/` and `services/` seaweedfs; `security/` kubescape.

## Roadmap

- [x] Talos cluster - 1 control plane (scheduling on) + 1 worker.
- [x] Infrastructure:
  - [x] [Cilium](https://cilium.io/) CNI with eBPF datapath (no kube-proxy).
  - [x] [Cilium Gateway API](https://docs.cilium.io/en/stable/network/servicemesh/gateway-api/gateway-api/) - `internal` and `external` Gateways, L2-announced on the LAN.
  - [x] [ArgoCD](https://argoproj.github.io/cd/) for GitOps.
  - [x] [External Secrets](https://external-secrets.io/) + 1Password as the runtime secret path.
  - [x] [external-dns](https://github.com/kubernetes-sigs/external-dns) for dynamic DNS records via Cloudflare.
  - [x] [cert-manager](https://cert-manager.io/) for TLS certificates (DNS-01).
  - [x] [Longhorn](https://longhorn.io/) for replicated block storage.
  - [x] [kube-prometheus-stack](https://github.com/prometheus-operator/kube-prometheus) for metrics, alerting and Grafana.
  - [x] [Grafana Loki](https://grafana.com/oss/loki/) + [Alloy](https://grafana.com/docs/alloy/) for log aggregation.
  - [x] [Headlamp](https://headlamp.dev/) in-cluster.
  - [x] [KubeVirt](https://kubevirt.io/) + CDI for VMs on Kubernetes.
  - [x] [CNPG](https://cloudnativepg.io/) for Postgres, [mariadb-operator](https://github.com/mariadb-operator/mariadb-operator) for MariaDB.
  - [x] [Tailscale operator](https://tailscale.com/kb/1236/kubernetes-operator) for remote access.
  - [x] [Renovate](https://docs.renovatebot.com/) for chart and image versions.
  - [x] [SOPS](https://github.com/getsops/sops) + age for the bootstrap 1Password credential (not wired into ArgoCD). See [cluster/docs/argocd.md](cluster/docs/argocd.md#secrets).
- [x] Applications:
  - [x] Media stack - Jellyfin, Seerr, Radarr, Sonarr, Bazarr, Prowlarr, qBittorrent behind Gluetun.
  - [x] [n8n](https://n8n.io/) for workflow automation.
  - [x] [Authentik](https://goauthentik.io/) for SSO.
  - [x] [Mealie](https://mealie.io/) recipes, [Actual Budget](https://actualbudget.org/), [Gatus](https://gatus.io/) status page on `status.nulcell.com` (replaced Uptime Kuma, parked in `gitops/experimental/`).
  - [x] [Cloudflare Tunnel](https://developers.cloudflare.com/cloudflare-one/networks/connectors/cloudflare-tunnel/) publishing internal apps to the internet.
  - [x] Portfolio website - Astro + nginx on `nulcell.com`.
- [ ] Serverless and Messaging:
  - [ ] [RabbitMQ Operator](https://github.com/rabbitmq/cluster-operator) for messaging.
  - [ ] [Knative Operators](https://knative.dev/docs/install/operator/knative-with-operators/) for serverless workloads.
    - [ ] [Serving](https://knative.dev/docs/serving/) for request-driven autoscaling.
    - [ ] [Eventing](https://knative.dev/docs/eventing/) for event-driven architecture.
    - [ ] [RabbitMQ plugin](https://knative.dev/docs/install/eventing/rabbitmq-install/) for messaging events.
- [ ] Security tooling:
  - [x] [Falco](https://falco.org/) (modern eBPF) + [Falcosidekick](https://github.com/falcosecurity/falcosidekick) + [Falco Talon](https://docs.falco-talon.org/) for runtime detection and automated response.
  - [x] [Trivy Operator](https://aquasecurity.github.io/trivy-operator/) for continuous vulnerability and config scanning, with the Headlamp plugin.
  - [ ] [Kyverno](https://kyverno.io/) for policy enforcement and configuration validation. See [gitops/security/README.md](gitops/security/README.md).
  - [ ] [Policy Reporter](https://kyverno.github.io/policy-reporter/) for aggregating `PolicyReport` CRDs.
- [ ] Provisioning:
  - [x] [helmfile](https://helmfile.readthedocs.io/) bootstrap ([`cluster/bootstrap/helmfile.yaml`](cluster/bootstrap/helmfile.yaml)).
  - [ ] Terraform + Terragrunt for Talos + bootstrap - plan in [cluster/docs/terraform.md](cluster/docs/terraform.md).
  - [ ] Pi-hole (DNS + DHCP) + netboot + Tailscale on a Raspberry Pi for bare-metal provisioning.
- [ ] Testing:
  - [ ] [Kube-monkey](https://github.com/asobti/kube-monkey) for chaos testing.
- [ ] Backups ([runbook](cluster/docs/backup-restore.md)):
  - [x] Longhorn volume backups to [AWS S3](https://aws.amazon.com/s3/) (opt-in per PVC).
  - [x] CNPG barman-cloud backups to S3 for gatus, mealie, n8n and authentik.
  - [ ] Point-in-time restore drill (`gitops/experimental/apps/pitr-test`, steps in the runbook).
- [ ] HA home cluster.
  - [ ] 2.5GbE network upgrade for cluster nodes.
  - [ ] Dedicated control-plane nodes with similar mini-pcs (1 -> 3, never 2).
  - [ ] 2-3 additional workers with other hardware.

## Architecture

### Deployed components

```mermaid
flowchart TD
    classDef external fill:#f9f,stroke:#333,stroke-width:2px;
    classDef gitops fill:#bbf,stroke:#333,stroke-width:2px;
    classDef routing fill:#bfb,stroke:#333,stroke-width:1px;
    classDef compute fill:#ffb,stroke:#333,stroke-width:1px;
    classDef storage fill:#fbb,stroke:#333,stroke-width:1px;
    classDef security fill:#f99,stroke:#333,stroke-width:1px;
    classDef obs fill:#dfd,stroke:#333,stroke-width:1px;

    subgraph Ext ["External / Cloud"]
        GH[GitHub repo - nulcell/homecloud]:::external
        CF[Cloudflare DNS + Tunnel]:::external
        OP[1Password vault]:::external
        TS[Tailscale]:::external
        S3[AWS S3 - backups]:::external
    end

    subgraph GitOps ["GitOps"]
        Argo[ArgoCD]:::gitops
        ESO[External Secrets Operator]:::gitops
        GH -->|Sync manifests| Argo
        OP -->|ClusterSecretStore| ESO
        ESO -->|Materialises Secrets| Argo
    end

    subgraph Networking ["Networking & Ingress"]
        GWi[Gateway 'internal' - 10.10.20.2]:::routing
        GWe[Gateway 'external' - 10.10.20.6]:::routing
        Cilium[Cilium CNI - eBPF, kube-proxy replacement, L2 announcements]:::routing
        ExtDNS[external-dns]:::routing
        CertMan[cert-manager]:::routing
        CFD[cloudflared DaemonSet]:::routing

        CF -->|Tunnel| CFD
        CFD -->|Origin request| GWi
        TS -->|Tailnet| Cilium
        GWi --> Cilium
        GWe --> Cilium
        GWi -.->|HTTPRoute hostnames| ExtDNS
        GWe -.->|HTTPRoute hostnames| ExtDNS
        ExtDNS --> CF
        CertMan -.->|wildcard-nulcell-tls via DNS-01| GWi
        CertMan -.-> GWe
    end

    subgraph DataStore ["Storage & Databases"]
        LH[Longhorn block storage]:::storage
        CNPG[CNPG operator]:::storage
        PGDB[Postgres - authentik, gatus, mealie, n8n]:::storage
        MDB[mariadb-operator]:::storage

        CNPG -->|Manages| PGDB
        PGDB -->|Claims PVs| LH
        LH -->|Volume backups| S3
        PGDB -->|Base backups + WAL| S3
    end

    subgraph Compute ["Compute & Workloads"]
        KVirt[KubeVirt + CDI]:::compute
        subgraph Apps ["Applications"]
            Media[media-stack - Jellyfin, arr apps, Gluetun]:::compute
            N8N[n8n]:::compute
            Auth[authentik]:::compute
            Misc[mealie, actual-budget, gatus, portfolio]:::compute
        end

        Cilium --> Apps
        Cilium --> KVirt
        Apps -->|Secrets| ESO
        Apps -->|Persistent storage| LH
        Apps -->|Database| DataStore
        KVirt -->|Claims PVs| LH
    end

    subgraph SecLayer ["Security"]
        Falco[Falco - modern eBPF + k8saudit]:::security
        FB[Fluent Bit - kube-apiserver audit logs]:::security
        FSide[Falcosidekick + UI]:::security
        Talon[Falco Talon - response actions]:::security
        Trivy[Trivy Operator - vulnerability and config scans]:::security

        FB -->|Audit webhook| Falco
        Falco -->|Alerts| FSide
        FSide -->|priority >= error| Talon
    end

    subgraph Observability ["Observability"]
        KPM[kube-prometheus-stack]:::obs
        Loki[Grafana Loki]:::obs
        Alloy[Grafana Alloy]:::obs
        Grafana[Grafana]:::obs

        Compute -->|Metrics| KPM
        Compute -->|Pod logs| Alloy
        Alloy --> Loki
        Loki -.->|Datasource| Grafana
        KPM --> Grafana
        FSide -->|Alerts >= error| KPM
    end

    Trivy -->|ServiceMonitor| KPM

    Argo -.->|Deploys & manages| Networking
    Argo -.->|Deploys & manages| DataStore
    Argo -.->|Deploys & manages| Compute
    Argo -.->|Deploys & manages| SecLayer
    Argo -.->|Deploys & manages| Observability
```

### Security (work in progress)

Detection and response run today; posture scanning is new and Falco will be tuned for its noise. Kyverno (policy) is planned.

```mermaid
flowchart LR
    Sys[Syscalls - modern eBPF driver]
    Audit[kube-apiserver audit log]
    FB{{Fluent Bit}}

    Audit -->|Talos audit log tail| FB
    FB -->|POST :9765/k8s-audit| Falco

    subgraph Falco ["Falco DaemonSet"]
        Rules[Rulesets - falco-rules, incubating, k8saudit]
        Plugins[Plugins - container, k8smeta, k8saudit, json]
    end

    Sys --> Falco
    Falco -->|JSON http_output :2801| Sidekick[Falcosidekick]

    Sidekick -->|WEBUI| UI[Falcosidekick UI + redis-stack]
    Sidekick -->|priority >= error| Talon[Falco Talon]
    Sidekick -->|priority >= error| AM[Alertmanager - kube-prometheus-stack]
    Talon -->|k8sevents notifier| Events[Kubernetes Events]

    subgraph Posture ["Posture scanning"]
        Trivy[Trivy Operator]
        TServer[Trivy server - vulnerability DB]
        Reports[(Report CRDs - vulnerabilities, config audit, secrets, RBAC, compliance)]

        Trivy -->|scan jobs| TServer
        Trivy --> Reports
    end

    Reports --> HL[Headlamp Trivy plugin]
    Trivy -->|ServiceMonitor| Prom[Prometheus]

    Kyverno[Kyverno - planned]:::planned
    Kyverno -.->|PolicyReports| PR[Policy Reporter - planned]:::planned
    classDef planned stroke-dasharray: 5 5;
```

### Hardware layout

```mermaid
flowchart TB
    subgraph Public ["Public Internet"]
        direction LR
        PubUser[Users / Clients]
        PrivUser[Admin / Operator]
        CFD[Cloudflare DNS]
        CFT[Cloudflare Tunnel]
        TS[Tailscale ZTNA]

        PubUser -->|DNS| CFD
        PubUser -->|HTTPS| CFT
        PrivUser -->|ZTNA| TS
    end

    subgraph Network ["Home Network - 10.10.16.0/20"]
        direction TB
        Router[Main router - 10.10.31.254, DNS]
        Switch[LAN switch]

        Router --> Switch

        subgraph Cluster ["HomeCloud Kubernetes Cluster"]
            direction LR
            K8sVIP[API VIP - k8s.nulcell.com / 10.10.25.25]
            CP1[talos-tgu-9aw - control plane, 10.10.17.5]
            W1[talos-ztk-5fl - worker, 10.10.27.254]
            LB[Cilium L2 LB pool - 10.10.20.0-254]

            K8sVIP <-->|VIP| CP1
            W1 -->|API| K8sVIP
            CP1 --- LB
            W1 --- LB
        end

        Switch <-->|LAN| Cluster
    end

    Router -->|WAN| Public
    CFT -->|cloudflared to internal Gateway| Cluster
    TS -->|ZTNA| Cluster
```
