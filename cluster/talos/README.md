# Talos

Machine-config patches for the Talos cluster. First install: [../docs/bootstrap.md](../docs/bootstrap.md). Talos and Kubernetes upgrades: [../docs/upgrade.md](../docs/upgrade.md).

## Layout

```
talos/
├── patches/
│   ├── common.yaml        # every node: DNS, NTP, kubelet, node IP, Longhorn user volume, iSCSI module, workload isolation
│   └── controlplane.yaml  # control plane: certSANs, etcd, apiserver, controller-manager/scheduler, VIP, CNI/proxy off
├── generated/             # `talosctl gen config` base + talosconfig - gitignored
├── secrets/               # secret.yaml, etcd snapshots - gitignored
└── *-final.yaml           # rendered configs (`mise run talos:render`) - gitignored
```

## What lives where

| What | Where |
| --- | --- |
| `patches/*.yaml`, versions + schematic (`.mise.toml`) | Git |
| `secrets/secret.yaml` - the bundle every cert and token derives from | 1Password (item `r4a42ogc32yp5gbtub476vxw6e`, section `secret`); `mise run talos:secrets` pulls it |
| `generated/`, `*-final.yaml` | Neither - `mise run talos:render` regenerates them; they embed secrets |
| `generated/talosconfig`, kubeconfig | Regenerate from the bundle (below) / `talosctl kubeconfig`; optionally keep talosconfig in 1Password |
| etcd snapshots | Off the laptop (e.g. the S3 backup bucket); with the bundle they hold every cluster secret |

## Image schematic

Built at [factory.talos.dev](https://factory.talos.dev/); the ID is `SCHEMATIC_ID` in `.mise.toml`, used by `talos:upgrade` and `talos:render`.

```yaml
customization:
  extraKernelArgs:
    - -lockdown
    - lockdown=integrity # `-arg` removes a default, plain `arg` adds
  systemExtensions:
    officialExtensions:
      - siderolabs/amd-ucode
      - siderolabs/amdgpu
      - siderolabs/iscsi-tools # Longhorn
      - siderolabs/util-linux-tools # Longhorn
```

A changed schematic (extensions, kernel args) has a new ID: bump `SCHEMATIC_ID`, then `mise run talos:upgrade <ip>` per node, worker first. Extensions only land through an upgrade.

## Changing machine config

`$CONTROLPLANE_IP` / `$WORKER_IP` come from `.mise.toml`. Worker first, then the control plane.

1. **Render** after editing `patches/` (or bumping `TALOS_VERSION` / `KUBERNETES_VERSION`):

   ```bash
   mise run talos:render
   ```

2. **Save a rollback copy** of the live config (holds secrets - delete once settled):

   ```bash
   talosctl -n $WORKER_IP get mc v1alpha1 -o jsonpath='{.spec}' > cluster/talos/secrets/worker-rollback.yaml
   ```

3. **Dry run** and read the diff - only the intended changes should show:

   ```bash
   talosctl -n $WORKER_IP apply-config --file cluster/talos/worker-final.yaml --dry-run
   ```

4. **Apply** and check:

   ```bash
   talosctl -n $WORKER_IP apply-config --file cluster/talos/worker-final.yaml
   kubectl get nodes
   talosctl -n $WORKER_IP service kubelet
   ```

5. **Control plane**: steps 2-4 with `$CONTROLPLANE_IP` and `controlplane-final.yaml`. The API drops for a minute when kube-apiserver, controller-manager, scheduler or etcd restart.

Rollback: `talosctl -n <ip> apply-config --file cluster/talos/secrets/<role>-rollback.yaml`. Most changes apply without a reboot.

## talosctl client

```bash
talosctl gen config homecloud https://k8s.nulcell.com:6443 --with-secrets cluster/talos/secrets/secret.yaml \
  --output-types talosconfig --output-dir cluster/talos/generated --force
talosctl config merge cluster/talos/generated/talosconfig
talosctl config endpoints $CONTROLPLANE_IP --context homecloud   # Talos API is per node, not behind the VIP
talosctl config nodes $CONTROLPLANE_IP $WORKER_IP --context homecloud
talosctl kubeconfig --merge --force --nodes $CONTROLPLANE_IP
```

## Day-2

```bash
talosctl health --nodes $CONTROLPLANE_IP
talosctl dashboard -n <ip>
talosctl -n <ip> get links                  # NIC names
talosctl -n <ip> dmesg -f
mise run cluster:shutdown                   # full power-off, see ../docs/shutdown.md
mise run cluster:start
talosctl reset --nodes <ip> --graceful=false --reboot=true   # wipes the node
```
