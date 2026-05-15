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
export TALOSCONFIG=$(pwd)/generated/talosconfig

# Generate the initial config
talosctl gen config homecloud https://<NODE_IP>:6443 --output-dir ./generated

# Patch + apply
talosctl machineconfig patch generated/controlplane.yaml \
  --patch @patches/controlplane.yaml \
  --output controlplane-final.yaml

talosctl apply-config --insecure --nodes <NODE_IP> --file controlplane-final.yaml

# Bootstrap etcd (ONCE, on ONE node, ever)
talosctl bootstrap --nodes <NODE_IP>

# Pull kubeconfig
talosctl kubeconfig ./kubeconfig

# Day-2
talosctl health
talosctl dashboard
talosctl upgrade --image factory.talos.dev/installer/<SCHEMATIC_ID>:v<VERSION>
talosctl upgrade-k8s --to <K8S_VERSION>
```
