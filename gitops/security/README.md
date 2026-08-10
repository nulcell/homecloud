# Security Stack

Wave 10. One Application today: `sec-falco`, generated from [`falco/`](falco/).

## Falco

Runtime threat detection and automated response, split across two directories:

- [`gitops/operators/falco/`](../operators/falco/) (wave 5) installs the `falco-operator` chart and its CRDs into the `falco-operator` namespace.
- [`falco/`](falco/) (wave 10) holds the CRs the operator reconciles, plus the two components it does not manage.

### Detection

| Piece     | Where                                           | Notes                                                                                                                              |
| --------- | ----------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------- |
| Engine    | `Falco` CR in [`falco.yaml`](falco/falco.yaml)  | Operator defaults: modern eBPF driver, Prometheus metrics on `:8765`.                                                              |
| Config    | `Config` CR in [`falco.yaml`](falco/falco.yaml) | Merged into `/etc/falco/config.d`. JSON output, `http_output` to `falcosidekick:2801`, rule-mode captures.                         |
| Rules     | [`rules.yaml`](falco/rules.yaml)                | Upstream OCI rulesets, load order by priority: `falco-rules` (10), `falco-incubating-rules` (20), k8saudit.                        |
| Overrides | [`custom-rules.yaml`](falco/custom-rules.yaml)  | Priority 90, so it loads last. Appends `not` clauses that suppress known-good Talos/Cilium/containerd behaviour.                   |
| Plugins   | [`plugins.yaml`](falco/plugins.yaml)            | `container` and `k8smeta` for metadata, `k8saudit` for the audit stream, `json`. Pulled from OCI and auto-added to `load_plugins`. |

### Audit-log path

Talos writes the kube-apiserver audit log to `/var/log/audit/kube/kube-apiserver.log`. Falco cannot tail it directly, so a `fluent-bit` DaemonSet ([`fluentbit-values.yaml`](falco/fluentbit-values.yaml)) tails it and POSTs to the `falco-k8saudit-webhook` Service on `:9765/k8s-audit`, where the `k8saudit` plugin listens inside each Falco pod. fluent-bit is installed from its own chart in [`kustomization.yaml`](falco/kustomization.yaml) - the operator does not manage it.

### Routing and response

`Component` CRs in [`components.yaml`](falco/components.yaml):

- **falcosidekick** - fan-out. Forwards `priority >= error` to Alertmanager (`kps-alertmanager.monitoring:9093`, alerts expire after 48h) and to Falco Talon (`falco-talon:2803`).
- **falcosidekick-ui** - event browser at `falcosidekick.nulcell.com` ([`httproutes.yaml`](falco/httproutes.yaml), `internal` Gateway), 1-day TTL. Needs RediSearch, so the backing `redis-stack` StatefulSet is hand-rolled in `components.yaml` rather than left to the operator.
- **metacollector** - feeds Kubernetes metadata to the `k8smeta` plugin on `:45000`.

**Falco Talon** ([`talon-values.yaml`](falco/talon-values.yaml)) is installed from its own chart, again outside the operator. It currently runs the chart's default ruleset with `k8sevents` as the only notifier, so responses land as Kubernetes Events rather than mutating workloads.

Both Falco and falcosidekick are scraped via ServiceMonitors in [`monitoring.yaml`](falco/monitoring.yaml).

## Planned: Kyverno

Not deployed. Kyverno is the intended policy engine over OPA Gatekeeper - policies are Kubernetes YAML rather than Rego, it emits `PolicyReport` CRDs natively for a future Policy Reporter, and its mutate/generate rules can inject repo-wide defaults (imagePullSecrets, baseline network policies) instead of every chart repeating them.

When it lands it becomes a second directory here, `gitops/security/kyverno/`, picked up automatically by the `security` ApplicationSet at wave 10.

## Parked

[`gitops/exprimental/security/`](../exprimental/security/) holds Kubescape and Trivy Operator manifests plus an older Falco layout. No ApplicationSet reads that tree, so none of it runs.
