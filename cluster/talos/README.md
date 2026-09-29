# Talos

Machine-config patches and operator state for the Talos cluster. See [../docs/bootstrap.md](../docs/bootstrap.md) for the full bootstrap flow.

## Layout

```
talos/
├── patches/        # machine-config patches applied on top of `talosctl gen config` output
├── generated/      # output of `talosctl gen config` - gitignored
└── secrets/        # `secrets.yaml` and `talosconfig` - gitignored, back up out of band
```

## Image schematic

The custom Talos image is built at [factory.talos.dev](https://factory.talos.dev/) with these extensions baked in:

- `siderolabs/iscsi-tools` - required by Longhorn
- `siderolabs/util-linux-tools` - required by Longhorn
- `siderolabs/amd-ucode` - AMD CPU microcode updates
- `siderolabs/amdgpu` - AMD GPU firmware (drop if not on AMD GPU hardware)

Kernel customizations:

```yaml
customization:
    extraKernelArgs:
        - -lockdown
        - --lockdown=integrity
    systemExtensions:
        officialExtensions:
            - siderolabs/amd-ucode
            - siderolabs/amdgpu
            - siderolabs/iscsi-tools
            - siderolabs/util-linux-tools
```

The **schematic ID** lives in `.mise.toml` `[env]` as `SCHEMATIC_ID` - `mise run talos:upgrade` uses it.

## Common commands

```bash
export TALOSCONFIG_PATH=cluster/talos/generated/talosconfig
# Must match machine.install.image in patches/{controlplane,worker}.yaml.
export INSTALLER=metal-installer
# SCHEMATIC_ID, TALOS_VERSION, KUBERNETES_VERSION come from .mise.toml [env] (loaded by mise in this repo).
export INSTALL_IMAGE=factory.talos.dev/${INSTALLER}/${SCHEMATIC_ID}:${TALOS_VERSION}

export NODE_IP=10.10.17.5
export WORKER_IP=10.10.27.254

# Generate secrets (ONCE, ever)
# talosctl gen secrets --output-file cluster/talos/secrets/secret.yaml

# Generate the initial config
talosctl gen config homecloud https://k8s.nulcell.com:6443 \
  --kubernetes-version ${KUBERNETES_VERSION} \
  --talos-version ${TALOS_VERSION} \
  --install-image ${INSTALL_IMAGE} \
  --install-disk /dev/nvme0n1 \
  --with-secrets cluster/talos/secrets/secret.yaml \
  --output-dir cluster/talos/generated --force
rm ~/.talos/config 
talosctl config merge $TALOSCONFIG_PATH --context homecloud
talosctl config endpoints k8s.nulcell.com --context homecloud
talosctl config nodes ${NODE_IP} ${WORKER_IP} --context homecloud

# Patch + apply
talosctl machineconfig patch cluster/talos/generated/controlplane.yaml \
  --patch @cluster/talos/patches/controlplane.yaml \
  --output cluster/talos/controlplane-final.yaml
talosctl validate --config cluster/talos/controlplane-final.yaml --mode metal
talosctl apply-config --insecure --nodes ${NODE_IP} --file cluster/talos/controlplane-final.yaml

# Bootstrap etcd (ONCE, on ONE node, ever)
talosctl bootstrap --nodes ${NODE_IP} --endpoints ${NODE_IP}

# Pull kubeconfig
talosctl kubeconfig --merge --force --nodes ${NODE_IP}
# OR, if you want to keep it separate:
talosctl kubeconfig cluster/talos/kubeconfig --nodes ${NODE_IP} 
export KUBECONFIG=cluster/talos/kubeconfig

# Approve CSRs if any are pending
kubectl get csr -o json | jq -r '.items[] | select(.status == {}) | .metadata.name' | xargs -r kubectl certificate approve

# Optional, add the worker node to the cluster (repeat for each worker)
export WORKER_IP=10.10.27.254
talosctl machineconfig patch cluster/talos/generated/worker.yaml \
  --patch @cluster/talos/patches/worker.yaml \
  --output cluster/talos/worker-final.yaml
talosctl validate --config cluster/talos/worker-final.yaml --mode metal
talosctl apply-config --insecure --nodes ${WORKER_IP} --file cluster/talos/worker-final.yaml
kubectl get csr -o json | jq -r '.items[] | select(.status == {}) | .metadata.name' | xargs -r kubectl certificate approve

# Go ahead and install the CNI and other addons
mise run bootstrap

# Day-2
talosctl get links
talosctl health --nodes ${NODE_IP}
talosctl dashboard
# Upgrades: bump SCHEMATIC_ID / TALOS_VERSION / KUBERNETES_VERSION (and the kubectl pin) in .mise.toml first.
# Nodes are discovered from the cluster: workers first, then control planes, one at a time.
# Each node: preflight, drain, upgrade, wait Ready, wait for Longhorn to be healthy again.
mise run preflight                # read-only: nodes Ready, attached volumes have 2 healthy replicas; logs each check
mise run talos:upgrade [node]     # node name or IP limits it to one node
mise run talos:upgrade-k8s        # prints the plan, asks to confirm

# Config changes (patches below) use the same flow; a reboot (with drain) only happens when required.
mise run talos:config [node]

# Graceful full shutdown / start (physical move): see gitops/root/safe-scaledown.md
mise run cluster:shutdown
mise run cluster:start            # after powering the nodes on

# Day never
talosctl reset --nodes ${NODE_IP} --graceful=false --reboot=true

# New schematic (added/removed system extensions): bump SCHEMATIC_ID in .mise.toml, then
mise run talos:config && mise run talos:upgrade
# talos:config injects install.image from .mise.toml, so the image in the patch files only
# matters at bootstrap.
```
