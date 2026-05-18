# MaaS (legacy)

Single-node [Canonical MaaS](https://maas.io/) install script used to PXE-boot and provision bare-metal nodes for this homelab.

> **Status:** slated for replacement. MaaS is heavyweight for a single rack. The plan is to retire this directory in favor of a Raspberry Pi running Pi-hole (DNS + DHCP), netboot for PXE, and Tailscale for remote access. Don't expand this script — net-new bare-metal provisioning work should target the replacement.

## Usage

```bash
sudo ./maas-single-node.sh
```

Targets Ubuntu 24.04 LTS. See the script for the exact set of packages and post-install steps.
