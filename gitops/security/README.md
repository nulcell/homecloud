# Security Stack

## Tool Responsibilities

### Kubescape

Configuration posture and policy enforcement.

- **Configuration scanning** — Evaluates cluster resources against NSA, MITRE ATT&CK, and CIS frameworks on a schedule
- **Node scanning** — Checks node-level security configuration (kernel hardening, host settings)
- **Network policy service** — Generates least-privilege NetworkPolicy recommendations based on observed traffic
- **Seccomp profile service** — Automatically generates seccomp profiles for workloads
- **Admission controller** — Enforces security policies at deploy time (currently disabled pending stability)

### Trivy Operator

Image vulnerability scanning and compliance reporting.

- **Vulnerability scanning** — Scans container images for CVEs and produces `VulnerabilityReport` CRDs per workload
- **SBOM generation** — Generates Software Bill of Materials for all images (`SBOMReport` CRDs)
- **Exposed secret scanning** — Detects credentials and tokens accidentally committed to images or ConfigMaps
- **RBAC assessment** — Identifies overprivileged service accounts and risky RBAC bindings (`RbacAssessmentReport` CRDs)
- **Infra assessment** — Checks etcd, kube-apiserver, and kubelet configurations
- **Compliance reporting** — Produces cluster-scoped compliance reports against CIS 1.23, NSA 1.0, PSS Baseline, and PSS Restricted

### Falco

Runtime threat detection and response.

- **Runtime detection** — eBPF-based syscall monitoring; alerts on suspicious process execution, file access, and network activity
- **HTTP detection** — Detects anomalous HTTP traffic patterns at runtime
- **Malware detection** — Identifies known malicious binaries executing in containers
- **Runtime observability** — Continuous behavioural profiling of running workloads
- **Response actions** (via Falco Talon) — Automated responses to detections (pod termination, network isolation, k8s events)
- **Alert routing** (via Falcosidekick) — Forwards alerts at `warning` severity and above to Alertmanager

## Namespace Exclusions

| Namespace                                         | Reason                                                                              |
| ------------------------------------------------- | ----------------------------------------------------------------------------------- |
| `kubescape`                                       | Avoid self-scanning the security stack                                              |
| `trivy`                                           | Trivy creates ephemeral scan jobs — scanning them floods Kubescape's operator queue |
| `longhorn-system`                                 | infra component                                                                     |
| `kube-system` / `kube-public` / `kube-node-lease` | System namespaces, no workload scanning                                             |
