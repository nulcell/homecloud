# Templates, ISOs, CKS Images, User Data, Custom CNI Configurations, etc

## OS Templates

General Options:

- Zone: All zones (or specify a zone if needed, but not recommended)
- Domain: root
- Account: admin
- Hypervisor: KVM
- Direct Download: false
- Arch: x86_64
- User Data: None
- User Data link policy: None
- Password Enabled: true (just because it could be needed and you can always discard the password. Always use SSH keys and access private VMs via ZTNA or VPN)
- HVM: true
- Featured: true
- Public: true
- Dynamically scalable: false (I don't believe this is supported by KVM anyway)

| URL                                                                                                           | Name                 | Description                  | Format | Root Disk Controller | OS Type      | Template Type | Extractable | For CKS |
| ------------------------------------------------------------------------------------------------------------- | -------------------- | ---------------------------- | ------ | -------------------- | ------------ | ------------- | ----------- | ------- |
| [Ubuntu 24.04 - Noble](https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img)         | Ubuntu 24.04 - Noble | Ubuntu 24.04 LTS Cloud Image | QCOW2  | scsi                 | Ubuntu 24.04 | USER          | false       | false   |
| [Debian 12 - Bookworm](https://cdimage.debian.org/images/cloud/bookworm/latest/debian-12-nocloud-amd64.qcow2) | Debian 12 - Bookworm | Debian 12 Bookworm           | QCOW2  | scsi                 | Debian 12    | USER          | false       | false   |

## CKS Images

General Options:

- Zone: All zones (or specify a zone if needed, but not recommended)
- Min. CPU cores: 2
- Min. memory (MiB): 4096 MB
- Direct download: false
- Arch: x86_64

| Semantic version | Name                              | URL                                                                                                                    |
| ---------------- | --------------------------------- | ---------------------------------------------------------------------------------------------------------------------- |
| 1.32.5           | cks-v1.32.5-calico-x86_64         | [v1.32.5-calico-x86_64](https://download.cloudstack.org/cks/setup-v1.32.5-calico-x86_64.iso)                           |
| 1.33.1           | cks-v1.33.1-calico_v3.30.0-x86_64 | [v1.33.1-calico-x86_64](https://download.cloudstack.org/cks/setup-v1.33.1-calico-x86_64.iso)                           |
| 1.34.2           | cks-v1.34.2-calico-x86_64         | [v1.34.2-cilium-x86_64](https://nulcell-apache-cks-images.s3.eu-central-1.amazonaws.com/cks-v1.34.2-calico-x86_64.iso) |
| 1.34.2           | cks-v1.34.2-cilium_v1.18.2-x86_64 | [v1.34.2-cilium-x86_64](https://nulcell-apache-cks-images.s3.eu-central-1.amazonaws.com/cks-v1.34.2-cilium-x86_64.iso) |

## SSH Keys

What can I say here... Generate an SSH key pair and upload the public key via CloudStack UI or API for use with your instances 🤷

## User Data Library

Here's a list of useful user data scripts that can be used to bootstrap instances on first boot:

- **cloud-default**:
  - Description:
  - Data: [source](../cloud-init/cloud-default.yaml)
  - User Data parameters: None
- **tailscale-router-debian**:
  - Description: Sets up Tailscale as a router on Debian-based systems
  - Data: [source](../cloud-init/tailscale-router-debian.yaml)
  - User Data parameters:
    - `tailscale_auth_key`: Tailscale auth key with "subnet router" capability
    - `network_router_cidr`: The CIDR of the network to be routed via Tailscale

## Custom CNI Configurations

- **cilium**:
  - Description: Cilium CNI configuration for CKS clusters using helm installation method
  - Data: [source](../cni-config/cilium.yaml)
  - User Data parameters:
    - `cilium_version`: Cilium version to install (e.g., "1.18.4")
