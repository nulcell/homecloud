# Upgrading Talos and Kubernetes

Talos (the OS) and Kubernetes upgrade separately; `talosctl upgrade` never touches the Kubernetes version. Upgrade Talos first, then Kubernetes. Run everything from the repo root so mise loads `$CONTROLPLANE_IP`, `$WORKER_IP` and the versions from `.mise.toml`.

Upstream: [Upgrading Talos](https://docs.siderolabs.com/talos/latest/configure-your-talos-cluster/lifecycle-management/upgrading-talos), [Upgrading Kubernetes](https://docs.siderolabs.com/kubernetes-guides/advanced-guides/upgrading-kubernetes), [support matrix](https://docs.siderolabs.com/talos/latest/getting-started/support-matrix), [releases](https://github.com/siderolabs/talos/releases).

## Rules

- Take the latest patch of every minor on the way (e.g. 1.13.2 → 1.13.latest → 1.14.latest); Talos only tests adjacent-minor migrations.
- Kubernetes must sit in the running Talos minor's supported range (support matrix). A new Kubernetes minor usually needs the next Talos minor first.
- Before a Kubernetes minor, check Cilium (`cluster/bootstrap/helmfile.yaml`) and Longhorn list it as tested.
- Read the target's release notes and the upgrade doc's "Before upgrade" section first.

## Step 0: Pre-flight

```bash
talosctl health --nodes $CONTROLPLANE_IP
kubectl get pdb -A | awk 'NR==1 || $5==0'
kubectl get volumes.longhorn.io -n longhorn-system -o custom-columns=NAME:.metadata.name,ROBUST:.status.robustness | grep -v healthy
kubectl get backups.postgresql.cnpg.io -A --sort-by=.metadata.creationTimestamp | tail -5
talosctl -n $CONTROLPLANE_IP etcd defrag
talosctl -n $CONTROLPLANE_IP etcd snapshot cluster/talos/secrets/etcd-$(date +%F).snapshot
```

Expect: health all OK (the node-ready, kube-proxy and CoreDNS checks may SKIP); only Longhorn `instance-manager-*` PDBs at 0 allowed; Longhorn prints only the header; CNPG backups from the last day; the API pauses briefly during defrag.

## Step 1: Bump and render

1. In `.mise.toml`: `talosctl` + `TALOS_VERSION` (Talos), or `kubectl` + `KUBERNETES_VERSION` (Kubernetes). `SCHEMATIC_ID` only changes with extensions or kernel args.
2. `mise install && talosctl version --client`
3. `mise run talos:render` - keeps `generated/` on the new versions so later config applies don't downgrade anything.

## Step 2: Talos - worker

```bash
mise run talos:upgrade $WORKER_IP
talosctl version -n $WORKER_IP | grep Tag         # client and server on the new version
kubectl get nodes                                  # Ready, not SchedulingDisabled
kubectl get rulesfile -n falco                     # all PROGRAMMED True
watch -n 10 "kubectl get volumes.longhorn.io -n longhorn-system -o jsonpath='{range .items[*]}{.status.robustness}{\"\n\"}{end}' | sort | uniq -c"
```

The node cordons, drains, installs to the inactive A/B slot, reboots and uncordons (45m drain / 90m total budget; follow with `talosctl -n $WORKER_IP dmesg -f`). Every volume shows `degraded` while the worker's replicas resync - wait for all `healthy`, or the control plane drain blocks.

## Step 3: Talos - control plane

```bash
mise run talos:upgrade $CONTROLPLANE_IP
kubectl uncordon talos-tgu-9aw                     # only if the task failed after "post check passed"
talosctl version -n $CONTROLPLANE_IP,$WORKER_IP | grep Tag
kubectl get nodes
```

The API is down for a few minutes while the only control plane reboots. Wait for all Longhorn volumes `healthy` again. Rollback: `talosctl rollback -n <ip>` (a failed boot rolls back on its own).

## Step 4: Kubernetes

```bash
mise run talos:upgrade-k8s -- --dry-run
mise run talos:upgrade-k8s
kubectl get nodes                                  # new VERSION on both
kubectl get pods -n kube-system -l tier=control-plane
```

Then apply the rendered config from step 1 to both nodes ([../talos/README.md](../talos/README.md#changing-machine-config)) so the machine config records the new images; the dry run should only show image tags.

## Notes

Things we've hit; most come from running a single control plane.

- **upgrade-k8s times out.** Each kube-apiserver restart takes the API down, so controller-manager/scheduler crashloop past talosctl's wait. Restart the stuck pod and rerun - finished components are skipped.
- **Control-plane Talos upgrade "fails" after `post check passed`.** Sometimes talosctl's final uncordon hits the API before it is back. The upgrade worked: uncordon by hand, don't rerun.
- **Drain stalls.** A PDB with zero allowed disruptions blocks it until the drain timeout. Single-replica workloads must not set `minAvailable: 1`; single-instance CNPG clusters set `enablePDB: false`. Longhorn's `instance-manager-*` PDB holds until every volume on the node detaches - wait, never kill the instance-manager pod (it cuts I/O for attached volumes).
- **Pods come back on the same node.** Only a cordoned node keeps them off; restarts before the upgrade cordons are plain reschedules.
- **Interrupting talosctl.** If the node shows `stage: running` (`talosctl get machinestatus`), isn't cordoned and machined logs show no upgrade, nothing is in progress and Ctrl-C is safe.
- **Falco after a reboot.** falco-operator checks rulesfile requirements before plugins are installed and never rechecks; it runs with `--enforce-requirements=false` so upstream rules still install.
- **etcd bloat.** A snapshot far larger than its key count suggests (715 MB for 5.8k keys, 164 MB after defrag) needs a defrag; the default quota is 2 GB.
- **Installer flavor.** The control plane was first installed with `metal-installer-secureboot`, everything now uses `metal-installer`. Fine while firmware SecureBoot is off (`talosctl get securitystate`) and no volume is TPM-encrypted.
- **Never patch on top of a patched config.** List entries append, so the live config ends up with duplicates. Always render from `generated/` with `mise run talos:render` and `apply-config` the result.
- **Longhorn data** lives in the `longhorn` `UserVolumeConfig` (`/var/mnt/longhorn`, a directory on `EPHEMERAL`). Upgrades keep it; a reset that wipes `EPHEMERAL` deletes the node's replicas.

## History: Talos 1.13 → 1.14 (done 2026-11-28)

1.14 split `v1alpha1` into documents, and `KubeletConfig` has no `extraMounts`, so Longhorn had to leave `/var/lib/longhorn` (a kubelet bind mount) first. Order used: upgrade Talos on both nodes with the old config; `talosctl patch mc` only the `UserVolumeConfig`; per node, disable the old Longhorn disk, delete the node's replicas, swap the disk for `/var/mnt/longhorn` and wait for the rebuild (Longhorn won't ready a second disk on the same filesystem); then apply the rendered multi-document config, worker first. Deliberately left out: `SecurityProfileConfig` (workload isolation - test Longhorn first) and the `VolumeConfig` mounting `EPHEMERAL` nosuid/nodev. etcd metrics stay on `:2381` via `listen-metrics-urls` (1.14 otherwise moves them to `:2383`).
