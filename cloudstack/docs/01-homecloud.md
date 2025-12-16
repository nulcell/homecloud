# HomeCloud Environment Setup

## Project Structure

### Domains

Generally avoid using the root domain for activities other than creating images, ISOs, roles, offerings, accounts, and projects.

| Name        | Network Domain     |
| ----------- | ------------------ |
| `homecloud` | homecloud.internal |

### Accounts & Users

Create the homecloud account that will own the resources for each environment. You can also create additional users under this account as needed.

| Role         | Username          | Domain    | Account     | Timezone         |
| ------------ | ----------------- | --------- | ----------- | ---------------- |
| Domain Admin | `homecloud-admin` | homecloud | `homecloud` | Europe/Amsterdam |

## Networking Configuration

### VPC Networks

You should be creating these in a project under a dedicated domain (or root domain if you don't want to create a new domain) for your CloudStack environment.

**Note**:

- Values for DNS1 & DNS2 can be left empty to use CloudStack's default DNS settings for the zone.
- Use the following CIDR with the following subnets (use custom ACLs depending on the services being deployed in each network):
  - VPC CIDR: `/24` (i.e., 256 IP addresses)
    - Network 1:
      - name: `pub-net-1` (the vpc name will be prefixed automatically when **vpc.tier.name.prepend** is set to true in global settings)
      - network offering: `acs.net.vpc.core-public-lb` (VPC Network with VpcVirtualRouter and Public LB)
      - gateway: `10.x.x.1`
      - netmask: `255.255.255.192` (i.e., /26)
      - acl: default-allow
    - Network 2:
      - name: `priv-net-1` (the vpc name will be prefixed automatically when **vpc.tier.name.prepend** is set to true in global settings)
      - network offering: `acs.net.vpc.core-internal-lb-vm` (VPC Network with VpcVirtualRouter and Internal LB VM)
      - gateway: `10.x.x.65`
      - netmask: `255.255.255.192` (i.e., /26)
      - acl: default-allow
    - Network 3:
      - name: `priv-net-2` (the vpc name will be prefixed automatically when **vpc.tier.name.prepend** is set to true in global settings)
      - network offering: `acs.net.vpc.core-internal-lb-vm` (VPC Network with VpcVirtualRouter and Internal LB VM)
      - gateway: `10.x.x.129`
      - netmask: `255.255.255.192` (i.e., /26)
      - acl: default-allow
    - Network 4:
      - name: `priv-net-3` (the vpc name will be prefixed automatically when **vpc.tier.name.prepend** is set to true in global settings)
      - network offering: `acs.net.vpc.core-internal-lb-vm` (VPC Network with VpcVirtualRouter and Internal LB VM)
      - gateway: `10.x.x.193`
      - netmask: `255.255.255.192` (i.e., /26)
      - acl: default-allow

| Name                 | Description                       | CIDR        | Network Domain          | VPC Offering                    | IPv4 address for the VR in this Network | Networks                                   |
| -------------------- | --------------------------------- | ----------- | ----------------------- | ------------------------------- | --------------------------------------- | ------------------------------------------ |
| `hc-vpc-prod` | Homecloud VPC Production Network  | 10.1.1.0/24 | homecloud-prod.internal | `acs.vpc.natted.redundant-core` | N/A                                     | Network 1, Network 2, Network 3, Network 4 |
| `hc-vpc-dev`  | Homecloud VPC Development Network | 10.0.0.0/24 | homecloud-dev.internal  | `acs.vpc.natted.core`           | N/A                                     | Network 1, Network 2                       |

### Isolated Networks

Create general-purpose isolated networks for miscellaneous use for resources that do not need to be in the VPC networks or for those resources that are shared across multiple environments, such as a Cluster API or ArgoCD/Flux.

| Name                       | Description                       | Zone             | Owner Type | Domain    | Account   | Project | Network Domain     | Network Offering                  | Gateway  | Netmask       |
| -------------------------- | --------------------------------- | ---------------- | ---------- | --------- | --------- | ------- | ------------------ | --------------------------------- | -------- | ------------- |
| `iso-net-shared` | Homecloud Shared Isolated Network | `zone-homecloud` | Account    | homecloud | homecloud | N/A     | homecloud.internal | `acs.net.isolated.core-redundant` | 10.2.2.1 | 255.255.255.0 |

### VPN

To access the VPC networks securely, a single Tailscale router can be set up with access to all networks that need to be accessed. This allows secure access to the resources within the VPC & Isolated networks without needing to assign public IP addresses to each resource.

Create an instance in with a single NIC in all networks that need to be accessed with the following configuration (generate an ephemeral single-use tailscale auth key from your Tailscale admin console for use during setup):

| Name                        | Image Template | Compute Offering   | Data Disk | Networks | SSH Key Pair   | Stored User Data          | network_router_cidr |
| --------------------------- | -------------- | ------------------ | --------- | -------- | -------------- | ------------------------- | ------------------- |
| `hc-vpn-router-prod` | Ubuntu 24.04   | acs.comp.gen.small | None      | _all_    | _your-ssh-key_ | `tailscale-router-debian` | `10.1.1.0/24`       |
| `hc-vpn-router-dev`  | Ubuntu 24.04   | acs.comp.gen.small | None      | _all_    | _your-ssh-key_ | `tailscale-router-debian` | `10.0.0.0/24`       |

### VPS

Create a VPS instance in each environment for general use. Use the following configuration:

| Name                 | Image Template       | Compute Offering   | Data Disk | Network                       | SSH Key Pair   | Stored User Data |
| -------------------- | -------------------- | ------------------ | --------- | ----------------------------- | -------------- | ---------------- |
| `hc-vps-prod` | Ubuntu 24.04 - Noble | acs.comp.mem.large | None      | homecloud-vpc-prod_priv-net-1 | _your-ssh-key_ | `cloud-default`  |
| `hc-vps-dev`  | Ubuntu 24.04 - Noble | acs.comp.gen.small | None      | homecloud-vpc-dev_priv-net-1  | _your-ssh-key_ | `cloud-default`  |

### Windows Desktop VM (Optional)

Follow the guidelines in the [Windows Desktop VM Setup](./05-windows-setup.md) document to create a Windows Desktop VM in the `homecloud-vpc-prod_priv-net-1` network for occasional use.

### Kubernetes Cluster

#### Managed CKS Clusters

Create a Kubernetes cluster in the environment VPC using whatever version. Pass the relevant CNI configuration for Cilium with the most recent supported version.

| Name                 | Description                              | Zone             | Hypervisor | Kubernetes version | Compute Offering    | Node root disk size (in GB) | Network                  | HA enabled | Cluster size (Worker nodes) | SSH key pair   | Show advanced settings | Enable CloudStack CSI Driver | Service Offering for Control Nodes | Template for Control Nodes | Service Offering for Worker Nodes | Template for Worker Nodes | Etcd Nodes | Service Offering for etcd Nodes | Template for etcd Nodes | CNI Configuration | CNI Configuration Parameters | Auto Scaling | Min Nodes | Max Nodes |
| -------------------- | ---------------------------------------- | ---------------- | ---------- | ------------------ | ------------------- | --------------------------- | ------------------------ | ---------- | --------------------------- | -------------- | ---------------------- | ---------------------------- | ---------------------------------- | -------------------------- | --------------------------------- | ------------------------- | ---------- | ------------------------------- | ----------------------- | ----------------- | ---------------------------- | ------------ | --------- | --------- |
| `hc-cks-prod` | Homecloud Production Kubernetes Cluster  | `zone-homecloud` | KVM        | 1.34.2             | acs.comp.mem.medium | 200                         | homecloud-vpc-prod_net-1 | true       | 5                           | _your-ssh-key_ | true                   | true                         | acs.comp.mem.large                 | None                       | acs.comp.mem.large                | None                      | 0          | N/A                             | N/A                     | cilium            | cilium_version: `1.18.4`     | true         | 3         | 10        |
| `hc-cks-dev`  | Homecloud Development Kubernetes Cluster | `zone-homecloud` | KVM        | 1.34.2             | acs.comp.mem.medium | 75                          | homecloud-vpc-dev_net-1  | false      | 2                           | _your-ssh-key_ | true                   | true                         | acs.comp.mem.large                 | None                       | acs.comp.mem.medium               | None                      | 0          | N/A                             | N/A                     | cilium            | cilium_version: `1.18.4`     | true         | 1         | 3         |

Note:

- When using the CloudStack CSI, be aware of the requirements on [GitHub](https://github.com/apalia/cloudstack-csi-driver?tab=readme-ov-file#requirements)

Post-deployment steps:

- Access the cluster via kubectl using the kubeconfig file downloaded from CloudStack UI and update the following in the `kubeconfig` (you can import it to `kubectl` using `kubectl konfig import -s ~/Downloads/kube.conf`)
  - Cluster: `hc-cks-prod` or `hc-cks-dev`
  - User: `hc-cks-prod-admin` or `hc-cks-dev-admin`
  - Context: `admin@hc-cks-prod` or `admin@hc-cks-dev`

#### Cluster API Clusters (Development)

Create Kubernetes clusters using Cluster API (CAPI) with CloudStack as the infrastructure provider. Follow the instructions to set up the management cluster and deploy workload clusters as needed.

- [Cluster API with CKS + Kubeadm](../compute/clusterapi/cks-kubeadm.md)
