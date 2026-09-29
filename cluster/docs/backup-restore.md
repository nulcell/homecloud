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

`gitops/experimental/restore-test/` is a 1Gi PVC plus a pod that writes `original` to `/data/marker`. The `apps` ApplicationSet deploys it as `app-restore-test` with your normal sync policy, so the drill exercises the real delete-and-recreate path. It lives in `experimental/` (not synced). To run the drill, `git mv gitops/experimental/restore-test gitops/apps/restore-test` and push; move it back afterwards.

1. Once `app-restore-test` is Healthy, `kubectl -n restore-test exec deploy/writer -- cat /data/marker` prints `original`.
2. Back it up: Longhorn UI > Volume `restore-test/data` > Create Backup, and wait for it to complete (or wait for 03:00). `kubectl -n longhorn-system get backupvolumes` then lists the volume.
3. Change it: `kubectl -n restore-test exec deploy/writer -- sh -c 'echo changed > /data/marker'`.
4. `mise run restore restore-test/data`, then pick a backup from the list (Enter = newest).
5. Pass when: the marker reads `original` again; the PVC is Bound to a `restore-<timestamp>` volume; `app-restore-test` is Synced/Healthy without any manual step; `kubectl get pv | grep restore-test` shows one PV.
6. Clean up: move it back to `gitops/experimental/` and push. The apps template has no deletion finalizer, so the resources stay: run `kubectl delete ns restore-test`, then delete the `restore-test` volume under Backup in the Longhorn UI to drop its S3 objects.

## Postgres (CNPG barman-cloud plugin)

WAL archiving plus a daily base backup (30-day retention) to `s3://nulcell-homecloud-backup/cnpg/<cluster>`, enabled on `gatus-postgres` (02:00), `mealie-postgres` (02:15), `n8n-postgres` (02:30) and `authentik-postgres` (02:45). Each app has a `postgres-backup.yaml` (ObjectStore + ScheduledBackup) and the plugin block on its Cluster (`values.yaml` for all but authentik, whose Cluster is `postgres-cluster.yaml`). Their PVCs keep the Longhorn `backup` label as a safety net until you have run the point-in-time restore below once; then drop the label.

To enable another cluster:

1. Add its namespace to the `backup-s3` ClusterExternalSecret.
2. Copy `postgres-backup.yaml` (change names and `destinationPath`), add it to the app's `kustomization.yaml`.
3. Add `plugins: [{name: barman-cloud.cloudnative-pg.io, isWALArchiver: true, parameters: {barmanObjectName: <cluster>}}]` to the Cluster (`datastores.<key>.cluster` for chart-rendered ones).

Check: `kubectl cnpg status -n <ns> <cluster>` (recovery window filled, WAL archiving OK) and objects under `cnpg/<cluster>/` in S3. Chart-rendered clusters need `datastores.<key>.networkPolicy.egress` for S3 (their policy is default-deny); raw clusters with no policy do not.

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

Drill on gatus first (lowest stakes): restore to a point in time into a new generation and check the data.

## Restore checklist after a full rebuild

1. Bootstrap the cluster; ArgoCD recreates everything, including the Longhorn backup target and secrets.
2. Longhorn lists the backups after `pollInterval` (5 min).
3. `mise run restore` each stateful app, recover each Postgres as above, reload media with the data loader.
