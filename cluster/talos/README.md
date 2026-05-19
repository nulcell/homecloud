# Talos

Machine-config patches and operator state for the Talos cluster. See [../docs/bootstrap.md](../docs/bootstrap.md) for the full bootstrap flow.

## Layout

```
talos/
├── patches/        # machine-config patches applied on top of `talosctl gen config` output
├── generated/      # output of `talosctl gen config` — gitignored
└── secrets/        # `secrets.yaml` and `talosconfig` — gitignored, back up out of band
```

## Image schematic

The custom Talos image is built at [factory.talos.dev](https://factory.talos.dev/) with these extensions baked in:

- `siderolabs/iscsi-tools` — required by Longhorn
- `siderolabs/util-linux-tools` — required by Longhorn
- `siderolabs/amd-ucode` — AMD CPU microcode updates
- `siderolabs/amdgpu` — AMD GPU firmware (drop if not on AMD GPU hardware)

Record the **schematic ID** somewhere you'll find it again — you need it for `talosctl upgrade`.

## Common commands

```bash
export TALOSCONFIG_PATH=$(pwd)/generated/talosconfig
export INSTALLER=metal-installer-secureboot
export SCHEMATIC_ID=65cf8364cd0de4cf7b851dc7067a2db83d0ba04f11d8635c6cd3334be6ffb825
export TALOS_VERSION=v1.13.2
export KUBERNETES_VERSION=v1.35.5
export INSTALL_IMAGE=factory.talos.dev/${INSTALLER}/${SCHEMATIC_ID}:${TALOS_VERSION}

export NODE_IP=10.10.17.5

# Generate secrets (ONCE, ever)
# talosctl gen secrets --output-file secrets/secret.yaml

# Generate the initial config
talosctl gen config homecloud https://k8s.nulcell.com:6443 \
  --kubernetes-version ${KUBERNETES_VERSION} \
  --talos-version ${TALOS_VERSION} \
  --install-image ${INSTALL_IMAGE} \
  --install-disk /dev/nvme0n1 \
  --with-secrets secrets/secret.yaml \
  --output-dir ./generated --force
talosctl config merge --config $TALOSCONFIG_PATH --context homecloud
talosctl config endpoints  ${NODE_IP} --context homecloud
talosctl config nodes ${NODE_IP} --context homecloud

# Patch + apply
talosctl machineconfig patch generated/controlplane.yaml \
  --patch @patches/controlplane.yaml \
  --output controlplane-final.yaml
talosctl validate --config controlplane-final.yaml --mode metal
talosctl apply-config --insecure --nodes ${NODE_IP} --file controlplane-final.yaml

# Bootstrap etcd (ONCE, on ONE node, ever)
talosctl bootstrap --nodes ${NODE_IP}
talosctl config endpoints 10.10.25.25 k8s.nulcell.com --context homecloud


# Pull kubeconfig
talosctl kubeconfig --merge
# OR, if you want to keep it separate:
talosctl kubeconfig ./kubeconfig
export KUBECONFIG=$(pwd)/kubeconfig

# Approve CSRs if any are pending
kubectl get csr -o json | jq -r '.items[] | select(.status == {}) | .metadata.name' | xargs -r kubectl certificate approve

# Optional, add the worker node to the cluster (repeat for each worker)
export WORKER_IP=10.10.27.254
talosctl machineconfig patch generated/worker.yaml \
  --patch @patches/worker.yaml \
  --output worker-final.yaml
talosctl validate --config worker-final.yaml --mode metal
talosctl apply-config --insecure --nodes ${WORKER_IP} --file worker-final.yaml
kubectl get csr -o json | jq -r '.items[] | select(.status == {}) | .metadata.name' | xargs -r kubectl certificate approve

# Go ahead and install the CNI and other addons
../bootstrap/install.sh

# Day-2
talosctl get links
talosctl health
talosctl dashboard
talosctl upgrade --image factory.talos.dev/${INSTALLER}/${SCHEMATIC_ID}:${TALOS_VERSION}
export KUBERNETES_VERSION_UPGRADE=v1.36.1
talosctl upgrade-k8s --from ${KUBERNETES_VERSION} --to ${KUBERNETES_VERSION_UPGRADE} --nodes ${NODE_IP} --dry-run

# Day never
talosctl reset --nodes ${NODE_IP} --graceful=false --reboot=true

# Regular patches
talosctl patch machineconfig --patch @cluster/talos/patches/controlplane.yaml --nodes 10.10.17.5
talosctl patch machineconfig --patch @cluster/talos/patches/worker.yaml --nodes 10.10.27.254
```
