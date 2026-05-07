# OpenStack — Single Node (Kolla-Ansible)

Single-node OpenStack 2025.1 (Epoxy) deployment via [kolla-ansible](https://docs.openstack.org/kolla-ansible/latest/user/quickstart.html), provisioned through MaaS on Ubuntu 24.04 LTS.

## Target host

| Resource                | Spec                                              |
| ----------------------- | ------------------------------------------------- |
| OS                      | Ubuntu 24.04 LTS (server, minimal)                |
| CPU                     | 16c / 32t (KVM nested virt enabled)               |
| RAM                     | 96 GB                                             |
| Disk                    | 2 TB SSD                                          |
| NIC1 (`eth0`, mgmt)     | Static IP `10.10.17.5` from MaaS (API + internal) |
| NIC2 (`eth1`, provider) | No IP — used as Neutron external bridge           |

## What gets deployed

- **Core**: Keystone, Glance, Nova (KVM), Neutron (OVN), Placement, Horizon
- **Block storage**: Cinder with LVM backend on the SSD
- **File storage**: Manila with LVM + NFS-Ganesha backend
- **Object storage**: Swift — kolla-ansible 2025.1 dropped its Swift role, so Swift runs as host-native apt packages registered with Keystone. Run [extras/swift/install-swift.sh](extras/swift/install-swift.sh) after `configure.sh`.
- **Load Balancing**: Octavia (amphora driver) — `install.sh` builds the amphora qcow2 image; `openstack loadbalancer ...` available after deploy
- **Managed Kubernetes**: Magnum + Heat (uses Octavia for cluster LBs) + Barbican
- **Managed databases**: Trove (mysql / postgresql / mariadb datastores registered — guest images are user-built)
- **DNS**: Designate (bind9 backend) — `configure.sh` creates a `homecloud.local.` zone and sets it as the dns_domain on the `public` network so VM port creates auto-publish A/PTR records via the Neutron–Designate integration.

## MaaS configuration

Configure the host in MaaS before commissioning:

### 1. Network — two interfaces

In MaaS, after commissioning, edit the machine's interfaces:

| Interface     | Subnet    | Mode                   | Notes                                                       |
| ------------- | --------- | ---------------------- | ----------------------------------------------------------- |
| `eth0` (NIC1) | mgmt VLAN | Static `10.10.17.5/24` | OpenStack API, internal endpoints, SSH                      |
| `eth1` (NIC2) | (none)    | Unconfigured           | **Do not assign an IP.** Neutron owns this NIC for `br-ex`. |

The defaults in [globals.yml](homecloud-kolla-ansible/globals.yml) assume interface names `eth0` / `eth1` (kernel-style naming). If MaaS commissions with predictable names instead (e.g. `enp1s0`), update `network_interface` and `neutron_external_interface` accordingly.

The provider NIC must be left with no IP and no VLAN/bridge in MaaS — kolla-ansible will plug it into the OVN external bridge during deploy.

### 2. Storage — single SSD

Default MaaS partitioning is fine. The installer will:

1. Reserve ~200 GB for the root filesystem (MaaS default).
2. Create a `cinder-volumes` LVM volume group on free space remaining on the SSD.
3. Create a `manila-volumes` LVM volume group from a sparse file under `/var/lib/manila/` (Manila + LVM driver doesn't share well with Cinder's VG on the same disk).

If you'd like a dedicated partition for `cinder-volumes`, pre-partition the SSD in MaaS and export the device path via `CINDER_LVM_DEVICE` before running `install.sh`.

### 3. Cloud-init user-data

Paste the contents of [openstack-single-node.yaml](openstack-single-node.yaml) into the MaaS machine's **Cloud-init user data** field before deploying. It will:

- Update + upgrade packages
- Install Docker, Python venv tooling, git, lvm2, nfs-common, qemu-kvm
- Configure sysctl + module loads required by Neutron/Magnum
- Create the `os-admin` user with your SSH key
- Clone this repo to `/opt/homecloud`
- Bootstrap a kolla-ansible Python venv

It does **not** run the deploy. After provisioning, SSH in and continue manually.

## Post-provisioning steps

```bash
# SSH in as os-admin
ssh os-admin@10.10.17.5

cd /opt/homecloud/openstack

# 1. Edit globals.yml — set kolla_internal_vip_address (a free IP on the mgmt subnet)
#    and confirm the network_interface / neutron_external_interface names match `ip a`.
sudo -E nano homecloud-kolla-ansible/globals.yml

# 2. Run the installer (LVM VGs, deploy, post-deploy)
sudo -E ./install.sh

# 3. After deploy succeeds, run the configurator (images, flavors, networks, magnum templates)
./configure.sh

# 4. Optional: install Swift (object storage). kolla 2025.1 removed the role,
#    so this script does an apt-based install and registers Swift with Keystone.
sudo -E ./extras/swift/install-swift.sh
```

The Horizon dashboard will be available at `http://<kolla_internal_vip_address>/`. Admin password is auto-generated and printed at the end of `install.sh`; it's also stored in `/etc/kolla/admin-openrc.sh`.

### `configure.sh` — home network defaults

`configure.sh` creates the `public` external network using these defaults (override via env vars):

| Var                | Default                             | Meaning                            |
| ------------------ | ----------------------------------- | ---------------------------------- |
| `PROVIDER_CIDR`    | `10.10.16.0/20`                     | External subnet (matches home LAN) |
| `PROVIDER_GATEWAY` | `10.10.31.254`                      | Upstream gateway / router          |
| `PROVIDER_POOL`    | `start=10.10.20.0,end=10.10.20.254` | Floating-IP allocation range       |
| `PROVIDER_DNS`     | `10.10.31.254`                      | DNS server pushed to tenants       |

Because the provider network shares the L2 segment with mgmt, the host IP `10.10.17.5` (mgmt) and floating IPs (`10.10.20.0/24`) live in the same subnet. Make sure the floating-IP range is excluded from any DHCP scope on the home router.

### Trove guest images

Trove datastore versions are registered for **mysql 8.0**, **postgresql 16**, and **mariadb 11**, but Trove can't actually provision instances until you supply guest images. Build them with [diskimage-builder](https://docs.openstack.org/trove/latest/admin/building_guest_images.html) and re-run `configure.sh` with the image names exported, e.g.:

```bash
TROVE_MYSQL_IMAGE=trove-mysql-guest \
TROVE_PG_IMAGE=trove-postgresql-guest \
TROVE_MARIADB_IMAGE=trove-mariadb-guest \
  ./configure.sh
```

## Files

| File                                                                       | Purpose                                                                                      |
| -------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------- |
| [openstack-single-node.yaml](openstack-single-node.yaml)                   | MaaS cloud-init user-data — base prereqs only                                                |
| [homecloud-kolla-ansible/globals.yml](homecloud-kolla-ansible/globals.yml) | Main kolla-ansible config                                                                    |
| [homecloud-kolla-ansible/inventory](homecloud-kolla-ansible/inventory)     | All-in-one inventory                                                                         |
| [homecloud-kolla-ansible/config/](homecloud-kolla-ansible/config/)         | Per-service config overrides                                                                 |
| [install.sh](install.sh)                                                   | LVM setup → kolla bootstrap → prechecks → deploy → post-deploy → amphora build               |
| [configure.sh](configure.sh)                                               | Uploads images + creates flavors, networks, magnum templates, datastores, DNS zones, secrets |
| [build-amphora.sh](build-amphora.sh)                                       | Builds the Octavia amphora qcow2 (Ubuntu+HAProxy) and uploads it tagged `amphora`            |
| [extras/swift/install-swift.sh](extras/swift/install-swift.sh)             | Native Swift install + Keystone registration (since kolla 2025.1 removed Swift)              |

## Operating notes

- **VIP**: `kolla_internal_vip_address` in [globals.yml](homecloud-kolla-ansible/globals.yml) must be a **free** IP on the same L2 segment as NIC1 — kolla's HAProxy will claim it via keepalived.
- **Container engine**: Docker (kolla default). Cluster CRI for Magnum is configured per cluster template.
- **TLS**: disabled in v1. To enable later set `kolla_enable_tls_internal: yes` / `kolla_enable_tls_external: yes` and provide certs under `/etc/kolla/certificates/`.
- **Logs**: containers write to `/var/log/kolla/<service>/`.
- **Reconfigure**: rerun `kolla-ansible -i inventory reconfigure` after editing globals or per-service config under `homecloud-kolla-ansible/config/`.
- **Upgrade**: `kolla-ansible upgrade` after bumping `openstack_release` in globals.

## Troubleshooting

```bash
# Activate the kolla venv
source /opt/kolla/venv/bin/activate
cd /opt/homecloud/openstack/homecloud-kolla-ansible

# Re-run prechecks
kolla-ansible -i inventory prechecks

# Tail container logs
tail -f /var/log/kolla/*/*.log

# Inspect a service container
docker ps | grep nova_api
docker logs nova_api

# Source admin credentials (after deploy)
source /etc/kolla/admin-openrc.sh
openstack endpoint list
```
