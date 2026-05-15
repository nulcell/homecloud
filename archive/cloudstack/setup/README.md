# CloudStack CLI

Single-file tool for CloudStack setup and management on Ubuntu 24.04 LTS.

## Installation

```bash
curl -O https://raw.githubusercontent.com/nulcell/homecloud/main/cloudstack/setup/cloudstack
chmod +x cloudstack
```

## Prerequisites

- Ubuntu 24.04 LTS
- Root access
- **Two bridge interfaces**: `cloudbr0` and `cloudbr1` (required on all KVM hosts including management server)
- Internet connectivity

### Bridge Setup

Both bridges are required on all nodes that will run VMs:

```bash
# Example netplan configuration (/etc/netplan/01-netcfg.yaml)
network:
  version: 2
  ethernets:
    eno1:
      dhcp4: false
    eno2:
      dhcp4: false
  bridges:
    cloudbr0:
      interfaces: [eno1]
      dhcp4: true
    cloudbr1:
      interfaces: [eno2]
      dhcp4: false
```

Apply with: `sudo netplan apply`

## Quick Start

### Single-Node Setup

```bash
sudo ./cloudstack all-in-one setup --cloudstack-version 4.22
```

Then:

1. Access UI: `http://<ip>:8080/client` (admin/password)
2. Create Zone → Pod → Cluster → Add Host → Add Storage
3. Run: `sudo ./cloudstack worker post-setup`
4. Reboot: `sudo reboot`

### Multi-Node Setup

**Management Node:**

```bash
sudo ./cloudstack management setup --cloudstack-version 4.22
sudo ./cloudstack storage nfs create
```

**Worker Nodes:**

```bash
sudo ./cloudstack worker configure --management-server http://<mgmt-ip>:8000
```

After adding hosts via UI:

```bash
sudo ./cloudstack worker post-setup
sudo reboot
```

## Commands

### Management

- `management setup` - Setup management server
- `management start|stop|restart|status` - Control service

### Storage

- `storage nfs create` - Create NFS exports
- `storage nfs status` - Check NFS status

### Worker

- `worker configure` - Configure KVM host
- `worker post-setup` - Run after adding to CloudStack
- `worker status` - Check status

### Database

- `database backup [--backup-dir /path]` - Backup database
- `database restore --backup-file /path/file.sql` - Restore database
- `database status` - Check status

### System

- `system status` - Check all components
- `system reset` - Reset state tracking

## Options

- `--cloudstack-version VERSION` - CloudStack version (default: 4.22)
- `--cloud-db-user USER` - DB user (default: cloud)
- `--cloud-db-password PASS` - DB password (default: cloud)
- `--mysql-db-host HOST` - MySQL host (default: localhost)
- `--management-server URL` - Management SSH key URL
- `-v, --verbose` - Verbose output
- `-f, --force` - Force operation

## Files

- State: `/var/lib/cloudstack/setup.state`
- Config: `/etc/cloudstack/cli.conf`
- Logs: `/var/log/cloudstack/setup.log`
- SSH Keys: `/var/lib/cloudstack/management/.ssh/`

## SSH Key Distribution

Management server automatically starts HTTP server on port 8000 serving SSH public key at `http://<mgmt-ip>:8000/id_rsa.pub`. Workers fetch this automatically during configuration.

## Troubleshooting

```bash
# View logs
sudo tail -f /var/log/cloudstack/setup.log

# Check state
sudo cat /var/lib/cloudstack/setup.state

# Reset and retry
sudo ./cloudstack system reset
sudo ./cloudstack management setup

# Manual SSH key (if auto-distribution fails)
cat /var/lib/cloudstack/management/.ssh/id_rsa.pub  # Copy to worker /root/.ssh/authorized_keys
```
