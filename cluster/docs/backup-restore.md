# Backup and restore

Bucket `nulcell-homecloud-backup` (`eu-central-1`), prefixes `longhorn/` and `cnpg/`. Credentials: 1Password item `backup-s3`, delivered as Secret `backup-s3` by the `backup-s3` ClusterExternalSecret ([`gitops/infrastructure/secrets/`](../../gitops/infrastructure/secrets/)). To add a namespace that needs it, add a `namespaceSelectors` entry.

## Volumes (Longhorn)

Opt-in per PVC (they cost money). `RecurringJob` `backup-daily` (03:00, keeps 7) backs up PVCs in the `backup` group. A PVC joins with these labels, set through `persistence.<name>.labels` (app-template >= 0.3.3), or `cluster.inheritedMetadata` (CNPG):

```
recurring-job.longhorn.io/source: enabled
recurring-job-group.longhorn.io/backup: enabled
```

Never labeled: `media-stack-data` (restore it with `manifests/loader-ssh.yaml`) and Prometheus.

Labeled in git: `media-stack-config`, `actualbudget-data`, `mealie-data` and the four Postgres PVCs. Everything else (Grafana, Alertmanager, Loki, Redis, VM disks) is deliberately not backed up. To back up another PVC whose chart cannot set labels, add a kustomize `patches` entry that adds them.

A new volume gets 2 replicas. Existing volumes are raised once:

```bash
kubectl -n longhorn-system patch volumes.longhorn.io <vol> --type merge -p '{"spec":{"numberOfReplicas":2}}'
kubectl -n longhorn-system get volumes.longhorn.io -o custom-columns=VOL:.status.kubernetesStatus.pvcName,REPLICAS:.spec.numberOfReplicas,HEALTH:.status.robustness
```

### Restore a PVC

```bash
mise run restore <namespace>/<pvc> [number]   # e.g. mealie/mealie-data
```

It lists the PVC's completed backups, newest first, and asks which to restore (a number; Enter picks 1, the newest). Pass the number as the second argument to skip the prompt. Backups are matched by the PVC they were taken from, not by volume, so history survives earlier restores (a restored PVC gets a new volume; its older backups stay under the old volume name).

ArgoCD is not paused. The script creates a Longhorn volume `fromBackup` and a PV pre-bound to the PVC's name, waits for the restore to finish, then deletes the PVC and the pods that mount it. Their replacements stay `Pending` until ArgoCD recreates the PVC from git; Kubernetes binds it to the pre-bound PV instead of provisioning an empty volume. The old volume is deleted (`reclaimPolicy: Delete`); backups stay in S3.

Not for Postgres PVCs (below).

#### Restore drill (throwaway app, nothing real is touched)

`gitops/experimental/apps/restore-test/` is a 1Gi PVC plus a pod that writes `original` to `/data/marker`. The `apps` ApplicationSet deploys it as `app-restore-test` with your normal sync policy, so the drill exercises the real delete-and-recreate path. It lives in `experimental/` (not synced) until you move it.

1. `git mv gitops/experimental/apps/restore-test gitops/apps/restore-test` and push. Once `app-restore-test` is Healthy, `kubectl -n restore-test exec deploy/writer -- cat /data/marker` prints `original`.
2. Back it up: Longhorn UI > Volume `restore-test/data` > Create Backup, and wait for it to complete (or wait for 03:00). `kubectl -n longhorn-system get backupvolumes` then lists the volume.
3. Change it: `kubectl -n restore-test exec deploy/writer -- sh -c 'echo changed > /data/marker'`.
4. `mise run restore restore-test/data`, then pick a backup from the list (Enter = newest).
5. Pass when: the marker reads `original` again; the PVC is Bound to a `restore-<timestamp>` volume; `app-restore-test` is Synced/Healthy without any manual step; `kubectl get pv | grep restore-test` shows one PV.
6. Clean up: `git mv gitops/apps/restore-test gitops/experimental/apps/restore-test` and push. The apps template has no deletion finalizer, so the resources stay: run `kubectl delete ns restore-test`, then delete the `restore-test` volume under Backup in the Longhorn UI to drop its S3 objects.

## Postgres (CNPG barman-cloud plugin)

Postgres is backed up only by barman, never by Longhorn: their PVCs are not in the `backup` group, because a volume snapshot of a running database is only crash-consistent and cannot restore to a point in time. WAL archiving plus a daily base backup (30-day retention) go to `s3://nulcell-homecloud-backup/cnpg/<cluster>`, enabled on `gatus-postgres` (02:00), `mealie-postgres` (02:15), `n8n-postgres` (02:30) and `authentik-postgres` (02:45). Each app has a `postgres-backup.yaml` (ObjectStore + ScheduledBackup) and the plugin block on its Cluster (`values.yaml` for all but authentik, whose Cluster is `postgres-cluster.yaml`).

To enable another cluster:

1. Add its namespace to the `backup-s3` ClusterExternalSecret.
2. Copy `postgres-backup.yaml` (change names and `destinationPath`), add it to the app's `kustomization.yaml`.
3. Add `plugins: [{name: barman-cloud.cloudnative-pg.io, isWALArchiver: true, parameters: {barmanObjectName: <cluster>}}]` to the Cluster (`datastores.<key>.cluster` for chart-rendered ones).

Check: `kubectl cnpg status -n <ns> <cluster>` (recovery window filled, WAL archiving OK) and objects under `cnpg/<cluster>/` in S3. Chart-rendered clusters need `datastores.<key>.networkPolicy.egress` for S3 (their policy is default-deny); raw clusters with no policy do not.

### Restore / point in time

Deleting a cluster whose manifest still says `initdb` is not a restore: it creates an empty database with a new system ID, and barman refuses to archive it into the old non-empty path (`Expected empty archive`, WAL archiving never starts). Restore by recovering into a new cluster instead.

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

#### Point-in-time drill (throwaway database)

`gitops/experimental/apps/pitr-test/` is a 1Gi CNPG cluster `pitr-test-postgres` with barman backups and its own copy of the S3 keys; `restore.yaml` beside it recovers a second cluster from its archive. Nothing real is touched.

1. Move it into the synced tree: `git mv gitops/experimental/apps/pitr-test gitops/apps/pitr-test`, push, wait for `app-pitr-test` to be Healthy.
2. Take a base backup and wait for it: `kubectl cnpg backup -n pitr-test pitr-test-postgres --method plugin --plugin-name barman-cloud.cloudnative-pg.io`; `kubectl cnpg status -n pitr-test pitr-test-postgres` then shows a recovery window.
3. Insert two rows about ten seconds apart and read their commit times from the table itself:
   ```bash
   kubectl cnpg psql -n pitr-test pitr-test-postgres -- -d app -c "create table t(n int, at timestamptz default clock_timestamp()); insert into t(n) values (1);"
   sleep 10
   kubectl cnpg psql -n pitr-test pitr-test-postgres -- -d app -c "insert into t(n) values (2); select pg_switch_wal();"
   kubectl cnpg psql -n pitr-test pitr-test-postgres -- -d app -c "select n, at from t order by n"
   ```
   Wait a minute so the WAL holding both rows is archived (`Last Archived WAL` in `kubectl cnpg status`).
4. In `restore.yaml` set `targetTime` to a moment between the two `at` values, e.g. row 1's `at` plus three seconds, in UTC (`"2026-01-01 12:00:03+00"`). Don't take it from `date`: it truncates to whole seconds, so it can land *before* row 1 and recovery then stops with an empty database. Add `restore.yaml` to `kustomization.yaml` `resources`, push.
5. Pass when: the marker reads `original` again; the PVC is Bound to a `restore-<timestamp>` volume; `app-restore-test` is Synced/Healthy without any manual step; `kubectl get pv | grep restore-test` shows one PV.
6. Clean up: `git mv gitops/apps/restore-test gitops/experimental/apps/restore-test` and push. The apps template has no deletion finalizer, so the resources stay: run `kubectl delete ns restore-test`, then delete the `restore-test` volume under Backup in the Longhorn UI to drop its S3 objects.

## Postgres (CNPG barman-cloud plugin)

Postgres is backed up only by barman, never by Longhorn: their PVCs are not in the `backup` group, because a volume snapshot of a running database is only crash-consistent and cannot restore to a point in time. WAL archiving plus a daily base backup (30-day retention) go to `s3://nulcell-homecloud-backup/cnpg/<cluster>`, enabled on `gatus-postgres` (02:00), `mealie-postgres` (02:15), `n8n-postgres` (02:30) and `authentik-postgres` (02:45). Each app has a `postgres-backup.yaml` (ObjectStore + ScheduledBackup) and the plugin block on its Cluster (`values.yaml` for all but authentik, whose Cluster is `postgres-cluster.yaml`).

To enable another cluster:

1. Add its namespace to the `backup-s3` ClusterExternalSecret.
2. Copy `postgres-backup.yaml` (change names and `destinationPath`), add it to the app's `kustomization.yaml`.
3. Add `plugins: [{name: barman-cloud.cloudnative-pg.io, isWALArchiver: true, parameters: {barmanObjectName: <cluster>}}]` to the Cluster (`datastores.<key>.cluster` for chart-rendered ones).

Check: `kubectl cnpg status -n <ns> <cluster>` (recovery window filled, WAL archiving OK) and objects under `cnpg/<cluster>/` in S3. Chart-rendered clusters need `datastores.<key>.networkPolicy.egress` for S3 (their policy is default-deny); raw clusters with no policy do not.

### Restore / point in time

Deleting a cluster whose manifest still says `initdb` is not a restore: it creates an empty database with a new system ID, and barman refuses to archive it into the old non-empty path (`Expected empty archive`, WAL archiving never starts). Restore by recovering into a new cluster instead.

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

#### Point-in-time drill (throwaway database)

`gitops/experimental/apps/pitr-test/` is a 1Gi CNPG cluster `pitr-test-postgres` with barman backups and its own copy of the S3 keys; `restore.yaml` beside it recovers a second cluster from its archive. Nothing real is touched.

1. Move it into the synced tree: `git mv gitops/experimental/apps/pitr-test gitops/apps/pitr-test`, push, wait for `app-pitr-test` to be Healthy.
2. Take a base backup and wait for it: `kubectl cnpg backup -n pitr-test pitr-test-postgres --method plugin --plugin-name barman-cloud.cloudnative-pg.io`; `kubectl cnpg status -n pitr-test pitr-test-postgres` then shows a recovery window.
3. Insert a row, note the time, insert a second row:
   ```bash
   kubectl cnpg psql -n pitr-test pitr-test-postgres -- -d app -c "create table t(n int, at timestamptz default now()); insert into t(n) values (1);"
   date -u +"%Y-%m-%d %H:%M:%S+00"          # this is targetTime
   kubectl cnpg psql -n pitr-test pitr-test-postgres -- -d app -c "insert into t(n) values (2);"
   ```
   Wait about a minute (or `select pg_switch_wal();`) so the WAL holding both rows is archived.
4. In `restore.yaml` set `targetTime` to the time from step 3, add `restore.yaml` to `kustomization.yaml` `resources`, push.
5. Pass when `pitr-test-restored` becomes healthy and `kubectl cnpg psql -n pitr-test pitr-test-restored -- -d app -c "select n from t"` returns only `1`. An empty database means `targetTime` is earlier than row 1's `at`; to retry, fix it, push, then `kubectl -n pitr-test delete cluster pitr-test-restored` (recovery only runs when a cluster is created).
6. Clean up: `git mv gitops/apps/pitr-test gitops/experimental/apps/pitr-test` (and drop `restore.yaml` from `resources`), push, `kubectl delete ns pitr-test`, and delete `cnpg/pitr-test-postgres/` in S3.

## Restore checklist after a full rebuild

1. Bootstrap the cluster; ArgoCD recreates everything, including the Longhorn backup target and secrets.
2. Longhorn lists the backups after `pollInterval` (5 min).
3. `mise run restore` each stateful app, recover each Postgres as above, reload media with the data loader.
