# Backup and restore

Bucket `nulcell-homecloud-backup` (`eu-central-1`), prefixes `longhorn/` and `cnpg/`. Credentials: 1Password item `backup-s3`, delivered as Secret `backup-s3` by the `backup-s3` ClusterExternalSecret ([`gitops/infrastructure/secrets/`](../../gitops/infrastructure/secrets/)). To add a namespace that needs it, add a `namespaceSelectors` entry.

## Volumes (Longhorn)

Opt-in per PVC. `RecurringJob` `backup-daily` (03:00, keeps 7) backs up volumes in the `backup` group. Two ways in:

- **New PVCs: `storageClass: longhorn-backup`.** The class carries the group, so it works with any chart that accepts a storage class and needs no labels. `storageClassName` is immutable, so this cannot be applied to an existing PVC. Bulk media stays on `longhorn`.
- **Existing PVCs: label them** (below), through `persistence.<name>.labels` in app-template >= 0.3.3, a kustomize patch for other charts, or `kubectl label`. Labels join a PVC to the group whatever its class.

Labels:

```
recurring-job.longhorn.io/source: enabled
recurring-job-group.longhorn.io/backup: enabled
```

Never labeled: `media-stack-data` (restore it with `manifests/loader-ssh.yaml`) and Prometheus.

Labels are in git for `media-stack-config`, `actualbudget-data`, `mealie-data` and the four Postgres PVCs. Others (StatefulSet claim templates are immutable) are labeled by hand, and lost if the PVC is recreated:

```bash
kubectl -n <ns> label pvc <pvc> recurring-job.longhorn.io/source=enabled recurring-job-group.longhorn.io/backup=enabled
```

A new volume gets 2 replicas. Existing volumes are raised once:

```bash
kubectl -n longhorn-system patch volumes.longhorn.io <vol> --type merge -p '{"spec":{"numberOfReplicas":2}}'
kubectl -n longhorn-system get volumes.longhorn.io -o custom-columns=VOL:.status.kubernetesStatus.pvcName,REPLICAS:.spec.numberOfReplicas,HEALTH:.status.robustness
```

### Restore a PVC

```bash
mise run restore <argocd-app> <namespace>/<pvc>   # e.g. app-mealie mealie/mealie-data
```

It restores from the newest backup of that PVC's volume: pauses the app (applicationset controller off, `automated` removed), scales the workload down, deletes the PVC, creates a Longhorn volume `fromBackup` plus a PV bound to the PVC name, then resumes so ArgoCD recreates the PVC onto the restored data. The old volume is deleted (`reclaimPolicy: Delete`); backups stay in S3.

Not for Postgres PVCs (below). Nondestructive drill first: restore into a scratch PVC from the Longhorn UI and diff it.

Longhorn cannot restore "latest backup" on PVC creation by itself (`fromBackup` needs one pinned URL and backups are keyed by the old `pvc-<uuid>`), hence the script.

## Postgres (CNPG barman-cloud plugin)

WAL archiving plus a daily base backup (02:00, 30-day retention) to `s3://nulcell-homecloud-backup/cnpg/<cluster>`. Enabled on `gatus-postgres` only ([`gitops/apps/gatus/postgres-backup.yaml`](../../gitops/apps/gatus/postgres-backup.yaml), plugin block in its `values.yaml`). Roll out to mealie, n8n and authentik after the gatus drill passes; drop each database's Longhorn `backup` label after its own drill.

To enable another cluster:

1. Add its namespace to the `backup-s3` ClusterExternalSecret.
2. Copy `postgres-backup.yaml` (change names and `destinationPath`), add it to the app's `kustomization.yaml`.
3. Add `plugins: [{name: barman-cloud.cloudnative-pg.io, isWALArchiver: true, parameters: {barmanObjectName: <cluster>}}]` to the Cluster (`datastores.<key>.cluster` for chart-rendered ones).

Check: `kubectl -n gatus get backups.postgresql.cnpg.io,scheduledbackups.postgresql.cnpg.io` and objects under `cnpg/gatus-postgres/` in S3.

### Restore / point in time

Deleting a cluster whose manifest still says `initdb` is not a restore: it creates an empty database with a new system ID, and barman refuses to archive it into the old non-empty path (`Expected empty archive`, WAL archiving never starts). Either add the recovery block below, or, to start over, empty `s3://nulcell-homecloud-backup/cnpg/<cluster>/`. A restore also needs a completed base backup: check `Recovery window` in `kubectl cnpg status`.

Recovery always creates a new cluster generation: the recovered cluster archives under a new `serverName`, because barman refuses to write into a non-empty path. With the ArgoCD app paused, edit the Cluster (for gatus, `datastores.postgres.cluster` in `values.yaml`):

```yaml
bootstrap:
  recovery:
    source: origin
    recoveryTarget:            # optional; omit to recover to the latest WAL
      targetTime: "2026-10-01 12:00:00+00"
externalClusters:
  - name: origin
    plugin:
      name: barman-cloud.cloudnative-pg.io
      parameters:
        barmanObjectName: gatus-postgres   # the ObjectStore holding the old archive
        serverName: gatus-postgres         # archive name the old cluster wrote under
plugins:
  - name: barman-cloud.cloudnative-pg.io
    isWALArchiver: true
    parameters:
      barmanObjectName: gatus-postgres
      serverName: gatus-postgres-2         # new generation; bump on every restore
```

Then delete the Cluster and its PVC, resync. CNPG runs the recovery job and starts the new primary. Afterwards the `bootstrap.recovery` block can stay (it is only read at creation).

Drill on gatus first: confirm a base backup and WAL in S3, restore to a point in time into a throwaway name, check the data.

## Restore checklist after a full rebuild

1. Bootstrap the cluster; ArgoCD recreates everything, including the Longhorn backup target and secrets.
2. Longhorn lists the backups after `pollInterval` (5 min).
3. `mise run restore` each stateful app, recover each Postgres as above, reload media with the data loader.
