# Upgrading Talos and Kubernetes

Talos (the OS) and Kubernetes upgrade separately; `talosctl upgrade` never touches the Kubernetes version. Upgrade Talos first, then Kubernetes.

Upstream: [Upgrading Talos](https://docs.siderolabs.com/talos/latest/configure-your-talos-cluster/lifecycle-management/upgrading-talos), [Upgrading Kubernetes](https://docs.siderolabs.com/kubernetes-guides/advanced-guides/upgrading-kubernetes), [support matrix](https://docs.siderolabs.com/talos/latest/getting-started/support-matrix), [releases](https://github.com/siderolabs/talos/releases).

## Rules

- Take the latest patch of every minor on the way (e.g. 1.13.2 → 1.13.latest → 1.14.latest); Talos only tests adjacent-minor migrations.
- Kubernetes must sit in the running Talos minor's supported range (support matrix). A new Kubernetes minor usually needs the next Talos minor first.
- Versions live in `.mise.toml`: `talosctl` / `kubectl` in `[tools]`, `TALOS_VERSION` / `KUBERNETES_VERSION` / `SCHEMATIC_ID` and node IPs in `[env]`.
- Read the target's release notes and the upgrade doc's "Before upgrade" section first.

## Pre-flight

```bash
talosctl health --nodes $CONTROLPLANE_IP     # kube-proxy SKIP is expected (Cilium)
kubectl get pdb -A | awk 'NR==1 || $5==0'     # only Longhorn instance-manager-* may show 0 allowed

# Longhorn: header only when every volume is healthy
kubectl get volumes.longhorn.io -n longhorn-system \
  -o custom-columns=NAME:.metadata.name,ROBUST:.status.robustness | grep -v healthy

kubectl get backups.postgresql.cnpg.io -A --sort-by=.metadata.creationTimestamp | tail -5

talosctl -n $CONTROLPLANE_IP etcd defrag    # API pauses briefly
talosctl -n $CONTROLPLANE_IP etcd snapshot cluster/talos/secrets/etcd-$(date +%F).snapshot
```

## Talos

1. Bump `talosctl` and `TALOS_VERSION` in `.mise.toml` and `machine.install.image` in both `cluster/talos/patches/*.yaml`. `SCHEMATIC_ID` changes only with extensions or kernel args.
2. One node at a time, worker first:

   ```bash
   mise run talos:upgrade $WORKER_IP
   # wait for Longhorn volumes to be healthy again
   mise run talos:upgrade $CONTROLPLANE_IP
   kubectl uncordon <control-plane-node>      # see notes
   talosctl version -n $CONTROLPLANE_IP,$WORKER_IP
   kubectl get nodes                           # all Ready, none SchedulingDisabled
   ```

   The task allows 45m to drain and 90m overall. Watch with `talosctl -n <ip> dmesg -f`. Rollback: `talosctl rollback -n <ip>` (a failed boot rolls back on its own).

## Kubernetes

```bash
# bump KUBERNETES_VERSION and kubectl in .mise.toml
mise run talos:upgrade-k8s -- --dry-run
mise run talos:upgrade-k8s
```

## Notes

Things we've hit; most come from running a single control plane.

- **upgrade-k8s times out.** Each kube-apiserver restart takes the API down, so controller-manager/scheduler crashloop past talosctl's wait. Restart the stuck pod and rerun - finished components are skipped.
- **Control-plane Talos upgrade "fails" after `post check passed`.** The upgrade worked; only talosctl's final uncordon hit the API before it was back. Uncordon by hand, don't rerun.
- **Drain stalls.** A PDB with zero allowed disruptions blocks it until the drain timeout. Single-replica workloads must not set `minAvailable: 1`; single-instance CNPG clusters set `enablePDB: false`. Longhorn's `instance-manager-*` PDB holds until every volume on the node detaches - wait, never kill the instance-manager pod (it cuts I/O for attached volumes).
- **Pods come back on the same node.** Only a cordoned node keeps them off; restarts before the upgrade cordons are plain reschedules.
- **Interrupting talosctl.** If the node shows `stage: running` (`talosctl get machinestatus`), isn't cordoned and machined logs show no upgrade, nothing is in progress and Ctrl-C is safe.
- **Falco after a reboot.** falco-operator checks rulesfile requirements before plugins are installed and never rechecks; it runs with `--enforce-requirements=false` so upstream rules still install. If only `custom-overrides` loads, check `kubectl get rulesfile -n falco`.
- **etcd bloat.** A snapshot far larger than its key count suggests (715 MB for 5.8k keys, 164 MB after defrag) means it needed a defrag; the default quota is 2 GB.
- **Installer flavor.** The task uses `metal-installer`; the control plane was first installed with `metal-installer-secureboot`. Switching is safe only while firmware SecureBoot is off (`talosctl get securitystate`) and no volume is TPM-encrypted.
- **`generated/` goes stale.** It is pinned to the Kubernetes version it was generated with. Regenerate it before any `apply-config` or the rendered config downgrades the control plane, and diff against the live config (`talosctl -n <ip> get mc v1alpha1 -o yaml`) - applying a patch over an already-patched config appends list entries twice.
- **`extraKernelArgs`.** The Talos 1.13+ upgrade API ignores `machine.install.extraKernelArgs`. Kernel args here come from the schematic and nodes boot the UKI cmdline, so it doesn't apply.
- **Longhorn data.** `/var/lib/longhorn` is on `EPHEMERAL`, which upgrades keep (`install.wipe` applies only at install). A reset that wipes `EPHEMERAL` deletes replicas; the long-term fix is a `UserVolumeConfig` at `/var/mnt/longhorn` ([guide](https://docs.siderolabs.com/kubernetes-guides/csi/longhorn)).
- **Talos 1.14.** etcd metrics move from `2379` to `2383` (kube-prometheus-stack scrapes `2381` - check the target); workload isolation stays off on upgraded clusters (test Longhorn before enabling); many v1alpha1 fields are deprecated in favour of multi-document configs (`SysctlConfig`, `KernelModuleConfig`, `KubeNodeConfig`, ...); `apply-config --mode=reboot` is gone.
