# Safe cluster scale-down for physical move

Gracefully quiesce every Longhorn-backed workload so volumes **detach cleanly**, then
power the Talos nodes off. **No PVs/PVCs are deleted** - only replica counts change, so
data survives. On the way back, un-freezing ArgoCD restores everything from git
automatically.

> ⚠️ **Longhorn `reclaimPolicy: Delete`** (see [gitops/infrastructure/longhorn/values.yaml](gitops/infrastructure/longhorn/values.yaml#L19)).
> Deleting a **PVC** destroys its volume. This procedure never deletes PVCs - it only
> scales workloads to zero and (for Postgres) hibernates. Do **not** `kubectl delete pvc`.

---

## Why this isn't just "kubectl scale --all"

Three things fight a naïve scale-down, and several Longhorn volumes aren't owned by a
plain Deployment/StatefulSet at all:

| Layer                                             | What reverts / owns the pod                          | Handling                                                           |
| ------------------------------------------------- | ---------------------------------------------------- | ------------------------------------------------------------------ |
| **ArgoCD** `selfHeal: true` on every App (+ root) | re-syncs replicas back to git                        | **freeze first**: scale the two controllers to 0                   |
| **ApplicationSets** regenerate Apps               | would undo per-App edits                             | covered by freezing the appset-controller                          |
| **CNPG operator**                                 | owns Postgres pods directly (no Deploy/STS)          | `kubectl cnpg hibernate on`                                        |
| **mariadb-operator**                              | reconciles the MariaDB StatefulSet                   | scale operator to 0 first                                          |
| **prometheus-operator** (`kps-operator`)          | reconciles Prometheus/Alertmanager STS               | scale operator to 0 first                                          |
| **HPAs**                                          | re-inflate a zeroed Deployment to `minReplicas` (≥1) | **delete the HPA** before scaling (ArgoCD recreates it on restore) |
| **KubeVirt**                                      | owns `virt-launcher` pods via VirtualMachine CR      | you stop the VM (manifests/, not ArgoCD)                           |

Freezing ArgoCD is also exactly the "temporarily ignore OutOfSync apps" you asked for:
with the application-controller at 0 replicas, ArgoCD stops reconciling entirely. Apps
will read OutOfSync/Unknown and **nothing acts on it** until you scale the controller
back up.

> Stateless infra (cert-manager, external-dns, cloudflared, gateway, headlamp,
> tailscale, external-secrets, etc.) is intentionally **left running** - it owns no
> Longhorn volume, so it just dies with the node and is restored on boot. Do **not**
> scale down `longhorn-system`, `kube-system`, or `cnpg-system`: Longhorn/CSI must stay
> up to perform the detach, and the CNPG operator must stay up to process hibernation.

---

## ArgoCD apps & appsets in scope

**App-of-apps** (bootstrapped via Helm - *not* self-managed, so freezing it sticks):

- `root` (Application) → manages the ApplicationSets in [gitops/root/](gitops/root/)
  - [infrastructure-appset.yaml](gitops/root/infrastructure-appset.yaml) → `infra-*` Apps
  - [apps-appset.yaml](gitops/root/apps-appset.yaml) → `app-*` Apps
  - [operators-appset.yaml](gitops/root/operators-appset.yaml) → `operators-*` Apps
  - [security-appset.yaml](gitops/root/security-appset.yaml) → `sec-*` Apps
  - [services-appset.yaml](gitops/root/services-appset.yaml) → `services-*` Apps

All generated Apps carry `automated: { prune: true, selfHeal: true }`.

**Apps that own Longhorn volumes** (the ones this procedure quiesces):

| Volume / PVC                                | Namespace         | ArgoCD App                    | Controller          | Action                |
| ------------------------------------------- | ----------------- | ----------------------------- | ------------------- | --------------------- |
| `authentik-postgres-1`                      | authentik         | `app-authentik`               | CNPG                | hibernate             |
| `homarr-postgres-1`                         | homarr            | `app-homarr`                  | CNPG                | hibernate             |
| `n8n-postgres-1`                            | n8n               | `app-n8n`                     | CNPG                | hibernate             |
| `speedtest-tracker-postgres-1`              | speedtest-tracker | `app-speedtest-tracker`       | CNPG                | hibernate             |
| `storage-mariadb-cluster-0`                 | uptime-kuma       | `app-uptime-kuma`             | mariadb-operator    | operator→0, scale STS |
| `prometheus-…-db-…-0`                       | monitoring        | `infra-kube-prometheus-stack` | prometheus-operator | operator→0, scale STS |
| `alertmanager-…-db-…-0`                     | monitoring        | `infra-kube-prometheus-stack` | prometheus-operator | operator→0, scale STS |
| `grafana`                                   | monitoring        | `infra-kube-prometheus-stack` | Deployment          | scale to 0            |
| `storage-loki-0`                            | loki              | `infra-loki`                  | StatefulSet         | scale to 0            |
| `data-n8n-redis-0`                          | n8n               | `app-n8n`                     | StatefulSet         | scale to 0            |
| `falco-…-redis-0`                           | falco             | `sec-falco`                   | StatefulSet         | scale to 0            |
| `media-stack-config`, `media-stack-data`    | media             | `app-media-stack`             | Deploys + STS       | scale to 0            |
| `actualbudget-data`                         | actual-budget     | `app-actual-budget`           | Deployment          | scale to 0            |
| `speedtest-tracker-config`                  | speedtest-tracker | `app-speedtest-tracker`       | Deployment          | scale to 0            |
| `kubescape-storage`                         | kubescape         | `sec-kubescape`               | Deployment          | scale to 0            |
| `boot-volume`, `persistent-state-for-vps-*` | vps               | manifests/ (not ArgoCD)       | KubeVirt VM         | **you** stop the VM   |
| `windows-server-2025-*`                     | windows           | manifests/ (not ArgoCD)       | KubeVirt VM         | already Stopped ✓     |

Cluster facts captured at write time:

- Nodes - control-plane `talos-tgu-9aw` = **10.10.17.5**, worker `talos-ztk-5fl` = **10.10.27.254**
- 20 Longhorn volumes total; 2 (`windows-*`) already detached → expect **all 20 detached** before power-off.

---

## SHUTDOWN

Run from your workstation (context `admin@homecloud`). Do the steps **in order** - each
phase depends on the previous one having quiesced.

### 0. Pre-flight snapshot

```bash
kubectl config current-context           # expect: admin@homecloud
kubectl -n longhorn-system get volumes.longhorn.io \
  -o custom-columns='VOL:.metadata.name,STATE:.status.state,PVC:.status.kubernetesStatus.pvcName' \
  | tee /tmp/longhorn-before.txt
kubectl get applications.argoproj.io -n argocd \
  -o custom-columns='APP:.metadata.name,SYNC:.status.sync.status'
```

### 1. Freeze ArgoCD (stop reconciliation / ignore OutOfSync)

```bash
kubectl -n argocd scale statefulset argocd-application-controller   --replicas=0
kubectl -n argocd scale deployment  argocd-applicationset-controller --replicas=0

# CRITICAL: wait until the controller POD is actually gone - not just replicas=0.
# While that pod is still alive it self-heals your scale-downs straight back
# (replicas bounce 0->1 before pods even terminate), so the scale "does nothing".
kubectl -n argocd wait --for=delete pod \
  -l app.kubernetes.io/name=argocd-application-controller --timeout=120s
kubectl -n argocd get pods | grep -E 'application-controller|applicationset-controller' \
  || echo "✓ both controllers down - safe to scale workloads"
```

### 2. Stop the KubeVirt VM(s) - you handle this

Stop `vps` (and confirm `windows` stays stopped). When done, the VMI is gone:

```bash
kubectl -n vps get vmi          # expect: no resources
```

### 3. Hibernate the Postgres (CNPG) clusters

CNPG operator stays **up** to process this; hibernation fences the primary and detaches
its PVC cleanly.

```bash
for c in authentik/authentik-postgres homarr/homarr-postgres \
         n8n/n8n-postgres speedtest-tracker/speedtest-tracker-postgres; do
  kubectl cnpg hibernate on "${c#*/}" -n "${c%/*}"
done
# verify: each cluster shows hibernation complete, 0 pods
for ns in authentik homarr n8n speedtest-tracker; do kubectl -n "$ns" get pods -l cnpg.io/podRole=instance; done
```

### 4. Park the operators that would re-scale their StatefulSets

```bash
kubectl -n monitoring scale deployment kps-operator      --replicas=0   # prometheus-operator
kubectl -n mariadb    scale deployment mariadb-operator  --replicas=0
```

### 5. Delete HPAs, then scale all remaining workloads to 0

Two gotchas handled here:

- **HPAs** (`actualbudget`, `authentik-server`, `authentik-worker`, `n8n-worker`) pin
  `minReplicas: 1` and will re-inflate any Deployment you zero. Delete them first; ArgoCD
  recreates them from git on restore.
- **Shell word-splitting:** the loop iterates an **explicit literal list**, not a
  `$VAR`. In `zsh` (the default here) `for ns in $DATA_NS` does *not* split on spaces -
  it runs **one** iteration with `ns` set to the whole string, so every `kubectl -n` hits
  a non-existent namespace and you get `no objects passed to scale`.

Operators are already parked (step 4), so scaling their StatefulSets now sticks.

```bash
for ns in actual-budget authentik homarr media n8n speedtest-tracker \
          uptime-kuma loki monitoring falco kubescape; do
  # drop HPAs first (they force minReplicas >= 1)
  kubectl -n "$ns" delete hpa --all --ignore-not-found
  # scale only the kinds that exist -> no "no objects passed to scale" noise
  for kind in deployment statefulset; do
    [ -n "$(kubectl -n "$ns" get "$kind" -o name 2>/dev/null)" ] \
      && kubectl -n "$ns" scale "$kind" --all --replicas=0
  done
done
```

### 6. GATE - wait until every volume is detached

Do **not** power off until this shows `detached` for all 20 volumes (`windows-*` already are).

```bash
# macOS has no `watch` by default; use a shell loop (Ctrl-C to stop):
while true; do clear; kubectl -n longhorn-system get volumes.longhorn.io \
  -o custom-columns='VOL:.metadata.name,STATE:.status.state,NODE:.status.currentNodeID'; sleep 5; done
```

Anything stuck `attached`: find the lingering pod and stop its owner.

```bash
# which pods still mount PVCs:
kubectl get pods -A -o json | jq -r '.items[]
  | select(any(.spec.volumes[]?; .persistentVolumeClaim))
  | "\(.metadata.namespace)/\(.metadata.name)"'
```

### 7. Power off - worker first, control-plane last (use `--force`)

Use `--force`, which **skips the cordon/drain**. We already quiesced everything in steps
3–5 and confirmed every volume `detached` in step 6, so there is nothing left to drain.
A default (non-force) shutdown *would* drain, and with Longhorn's
`nodeDrainPolicy: block-for-eviction` + `defaultReplicaCount: 1`
([values.yaml](gitops/infrastructure/longhorn/values.yaml#L10-L11)) that drain blocks
while Longhorn tries to evict/rebuild the lone replica off the node - exactly the churn
you want to avoid. etcd survives the hard stop (WAL is fsync'd; `shutdown` doesn't remove
the member, so it rejoins on boot).

```bash
talosctl -n 10.10.27.254 shutdown --force    # worker  talos-ztk-5fl
talosctl -n 10.10.17.5  shutdown --force     # control-plane talos-tgu-9aw
```

> Only safe **because** step 6 showed all volumes detached. Don't `--force` past a
> still-`attached` volume - go back and stop whatever still mounts it.

Both nodes power off. Move them.

---

## RESTORE (next day)

### 1. Power on - control-plane first, then worker

Power `talos-tgu-9aw` (10.10.17.5) first; once the API answers, power `talos-ztk-5fl`.

```bash
kubectl get nodes                       # wait for both Ready
kubectl -n longhorn-system get volumes.longhorn.io   # volumes still detached, intact
```

### 2. Un-hibernate Postgres and operators (annotations don't auto-revert)

```bash
for c in authentik/authentik-postgres homarr/homarr-postgres \
         n8n/n8n-postgres speedtest-tracker/speedtest-tracker-postgres; do
  kubectl cnpg hibernate off "${c#*/}" -n "${c%/*}"
done

kubectl -n monitoring scale deployment kps-operator      --replicas=1   # prometheus-operator
kubectl -n mariadb    scale deployment mariadb-operator  --replicas=1
```

### 3. Unfreeze ArgoCD - it restores everything else

```bash
kubectl -n argocd scale statefulset argocd-application-controller   --replicas=1
kubectl -n argocd scale deployment  argocd-applicationset-controller --replicas=1
```

ArgoCD `selfHeal` now sees every scaled-to-0 Deployment/StatefulSet as OutOfSync and
restores git's replica counts, and **recreates the deleted HPAs**. `kps-operator` and
`mariadb-operator` are themselves ArgoCD-managed, so they come back too and then re-scale
the Prometheus/Alertmanager and MariaDB StatefulSets. (If you'd rather not wait on a
reconcile, scale those two operators to 1 by hand.)

### 4. Start the KubeVirt VM(s) - you handle this

### 5. Verify

```bash
kubectl get applications.argoproj.io -n argocd \
  -o custom-columns='APP:.metadata.name,SYNC:.status.sync.status,HEALTH:.status.health.status'
kubectl -n longhorn-system get volumes.longhorn.io \
  -o custom-columns='VOL:.metadata.name,STATE:.status.state,ROBUST:.status.robustness'
```

Expect Apps `Synced/Healthy` (the pre-existing `operators-kubevirt` OutOfSync is unrelated)
and all volumes `attached/healthy`.

---

## Rollback notes

- **Aborting mid-shutdown:** just run RESTORE steps 2–3. Nothing is destroyed; scaling is
  fully reversible.
- **A volume won't detach:** never force-delete the PVC. Instead find the mounting pod
  (step 6 snippet) and scale its owner; if a CNPG cluster is stubborn, confirm hibernate
  finished with `kubectl cnpg status <cluster> -n <ns>`.
- **App stuck OutOfSync after restore:** it's just waiting on the controller - confirm
  `argocd-application-controller` is at 1 replica and `Running`.
- **Scale-down won't stick (pods reappear / stay at 7d age):** something is re-inflating
  them. Check, in order: (1) the `argocd-application-controller` pod is actually gone
  (`kubectl -n argocd get pods | grep application-controller`); (2) no HPA is pinning it
  (`kubectl get hpa -A`); (3) the owning operator is parked (`kps-operator`,
  `mariadb-operator` at 0). Field manager tells you the culprit:
  `kubectl -n <ns> get deploy <name> -o jsonpath='{.metadata.managedFields[*].manager}'`.

</content>
</invoke>
