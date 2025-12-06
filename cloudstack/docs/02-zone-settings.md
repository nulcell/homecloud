# Zone Setup

## Basic Zone (Recommended for simplicity)

- Notes:
  - Ideal for simple environments with a single network
  - Using CKS won't be able to provision public IPs for Load Balancers

- **Zone Type**:
  - Description: Type of zone to create.
  - Value: Core
  - Value Description: Core Zones are intended for Datacenter based deployments and allow the full range of Networking and other functionality in Apache CloudStack. Core Zones have a number of prerequisites and rely on the presence of shared storage and helper Instances.
- **Core Zone Type**:
  - Description: The specific type of Core Zone to create.
  - Value: Basic
  - Value Description: Provide a single Network where each Instance is assigned an IP directly from the Network. Guest isolation can be provided through layer-3 means such as security groups (IP address source filtering).
- **Zone Details**:
  - Description: A Zone is the largest organizational unit in CloudStack, and it typically corresponds to a single datacenter. Zones provide physical isolation and redundancy. A zone consists of one or more Pods (each of which contains hosts and primary storage servers) and a secondary storage server which is shared by all pods in the zone.
  - Values:
    - \*Name: `zone-homecloud`
    - \*IPv4 DNS1: `10.10.31.254` # Replace with your preferred DNS server
    - IPv4 DNS2: `8.8.8.8` # Google Public DNS as secondary. You can also use `1.1.1.1` (Cloudflare) or another DNS server of your choice.
    - \*Internal DNS 1: `10.10.31.254` # Replace with your internal DNS server (e.g., your router or local DNS server)
    - Internal DNS 2: ``
    - \*Hypervisor: KVM
    - Network Offerings: Offering for Shared Security group enabled networks
    - Default network domain for Isolated networks: `homecloud.internal`
    - Dedicated: false
    - Enable local storage for User Instances: true
    - Enable local storage for System VMs: false
- **Network**:
  - **Physical Network**:
    - Description: When adding a basic Zone, you can set up one physical Network, which corresponds to a NIC on the hypervisor. The Network carries several types of traffic.
    - Values:
      - Network name: `cloudbr0`
      - Isolation method: VLAN
      - Traffic types (traffic label):
        - Management (cloudbr0)
        - Storage (cloudbr0)
        - Guest (cloudbr0)
  - **Pod**:
    - Description: Each Zone must contain one or more Pods. We will add the first pod now. A pod contains hosts and primary storage servers, which you will add in a later step. First, configure a range of reserved IP addresses for CloudStack's internal management traffic. The reserved IP range must be unique for each zone in the cloud.
    - Values:
      - Name: `pod-homecloud`
      - Reserved system gateway: `10.10.31.254` (Replace with your network gateway)
      - Reserved system netmask: `255.255.240.0` (Replace with your network netmask, this is an example for a /20 subnet)
      - Start reserved system IP: `10.10.21.1`
      - End reserved system IP: `10.10.21.254`
  - **Guest traffic**:
    - Description: Guest Network traffic is communication between end-user Instances. Specify a range of VLAN IDs or VXLAN Network identifiers (VNIs) to carry guest traffic for each physical Network.
    - Values:
      - Guest gateway: `10.10.31.254` (Replace with your network gateway)
      - Guest netmask: `255.255.240.0` (Replace with your network netmask, this is an example for a /20 subnet)
      - Guest start IP: `10.10.22.1`
      - Guest end IP: `10.10.22.254`
  - **Storage traffic**:
    - Description: Storage: Traffic between primary and secondary storage servers, such as Instance Templates and Snapshots.
    - Values:
      - Gateway: `10.10.31.254`
      - Netmask: `255.255.240.0`
      - VLAN/VNI range: ``
      - Start IP: `10.10.23.1`
      - End IP: `10.10.23.254`

## Advanced Zone (recommended for testing or more complex networking requirements)

- **Zone Type**:
  - Description: Type of zone to create.
  - Value: Core
  - Value Description: Core Zones are intended for Datacenter based deployments and allow the full range of Networking and other functionality in Apache CloudStack. Core Zones have a number of prerequisites and rely on the presence of shared storage and helper Instances.

### Security Groups Disabled

- **Core Zone Type**:
  - Description: The specific type of Core Zone to create.
  - Value: Advanced (Security Groups Disabled)
  - Value Description: This is recommended and allows more sophisticated Network topologies. This Network model provides the most flexibility in defining guest Networks and providing custom Network offerings such as firewall, VPN, or load balancer support.
- **Zone Details**:
  - Description: A Zone is the largest organizational unit in CloudStack, and it typically corresponds to a single datacenter. Zones provide physical isolation and redundancy. A zone consists of one or more Pods (each of which contains hosts and primary storage servers) and a secondary storage server which is shared by all pods in the zone.
  - Values:
    - \*Name: `zone-homecloud`
    - \*IPv4 DNS1: `10.10.31.254` # Replace with your preferred DNS server
    - IPv4 DNS2: `8.8.8.8` # Google Public DNS as secondary. You can also use `1.1.1.1` (Cloudflare) or another DNS server of your choice.
    - IPv6 DNS1: ``
    - IPv6 DNS2: ``
    - \*Internal DNS 1: `10.10.31.254` # Replace with your internal DNS server (e.g., your router or local DNS server)
    - Internal DNS 2: ``
    - \*Hypervisor: KVM
    - Default network domain for Isolated networks: `homecloud.internal`
    - Default guest CIDR for Isolated Networks: `10.0.0.0/24`
    - Enable local storage for User Instances: true
    - Enable local storage for System VMs: false

### Security Groups Enabled

- **Core Zone Type**:
  - Description: The specific type of Core Zone to create.
  - Value: Advanced (Security Groups Enabled)
  - Value Description: This is recommended and allows more sophisticated Network topologies. This Network model provides the most flexibility in defining guest Networks and providing custom Network offerings such as firewall, VPN, or load balancer support.
- **Zone Details**:
  - Description: A Zone is the largest organizational unit in CloudStack, and it typically corresponds to a single datacenter. Zones provide physical isolation and redundancy. A zone consists of one or more Pods (each of which contains hosts and primary storage servers) and a secondary storage server which is shared by all pods in the zone.
  - Values:
    - \*Name: `zone-homecloud`
    - \*IPv4 DNS1: `10.10.31.254` # Replace with your preferred DNS server
    - IPv4 DNS2: `8.8.8.8` # Google Public DNS as secondary. You can also use `1.1.1.1` (Cloudflare) or another DNS server of your choice.
    - IPv6 DNS1: ``
    - IPv6 DNS2: ``
    - \*Internal DNS 1: `10.10.31.254` # Replace with your internal DNS server (e.g., your router or local DNS server)
    - Internal DNS 2: ``
    - \*Hypervisor: KVM
    - Network Offerings: Offering for Shared Security group enabled networks
    - Default network domain for Isolated networks: `homecloud.internal`
    - Dedicated: false
    - Enable local storage for User Instances: true
    - Enable local storage for System VMs: false

### General Advanced Zone Setup Steps

- **Network**:
  - **Physical Network**:
    - Description: When adding a Zone, you need to set up one or more physical networks. Each physical network can carry one or more types of traffic, with certain restrictions on how they may be combined. Add or remove one or more traffic types onto each physical network.
    - Values:
      - Network name: `cloudbr0`
        - Isolation method: VLAN
        - Traffic types (traffic label):
          - Management (cloudbr0)
      - Network name: cloudbr1
        - Isolation method: VLAN
        - Traffic types (traffic label):
          - Public (cloudbr1) (only if Security Groups are disabled)
          - Storage (cloudbr1)
          - Guest (cloudbr1)
  - **Public Traffic** (only if Security Groups are disabled):
    - Description: Public traffic is generated when Instances in the cloud access the internet. Publicly-accessible IPs must be allocated for this purpose. End Users can use the CloudStack UI to acquire these IPs to implement NAT between their guest Network and their public Network. Provide at least one range of IP addresses for internet traffic.
    - Values:
      - Gateway: `10.10.31.254` (Replace with your network gateway)
      - Netmask: `255.255.240.0` (Replace with your network netmask, this is an example for a /20 subnet)
      - VLAN/VNI: `vlan://untagged`
      - Start IP: `10.10.20.1`
      - End IP: `10.10.20.254`
  - **Pod**:
    - Description: Each Zone must contain one or more Pods. We will add the first pod now. A pod contains hosts and primary storage servers, which you will add in a later step. First, configure a range of reserved IP addresses for CloudStack's internal management traffic. The reserved IP range must be unique for each zone in the cloud.
    - Values:
      - Name: `pod-homecloud`
      - Reserved system gateway: `10.10.31.254` (Replace with your network gateway)
      - Reserved system netmask: `255.255.240.0` (Replace with your network netmask, this is an example for a /20 subnet)
      - Start reserved system IP: `10.10.21.1`
      - End reserved system IP: `10.10.21.254`
  - **Guest traffic**:
    - Description: Guest Network traffic is communication between end-user Instances. Specify a range of VLAN IDs or VXLAN Network identifiers (VNIs) to carry guest traffic for each physical Network.
    - Values:
      - VLAN/VNI range: `500-700`
  - **Storage traffic**:
    - Description: Storage: Traffic between primary and secondary storage servers, such as Instance Templates and Snapshots.
    - Values:
      - Gateway: `10.10.31.254`
      - Netmask: `255.255.240.0`
      - VLAN/VNI range: ``
      - Start IP: `10.10.22.1`
      - End IP: `10.10.22.254`

## General Zone Setup Steps

- **Add Resources**:
  - **Clusters**:
    - Description: Each Pod must contain one or more Clusters. We will add the first cluster now. A cluster provides a way to group hosts. The hosts in a cluster all have identical hardware, run the same hypervisor, are on the same subnet, and access the same shared storage. Each cluster consists of one or more hosts and one or more primary storage servers.
    - Values:
      - Name: `cluster-homecloud`
      - Arch: AMD 64 bit (x86_64)
  - **IP Address (Host)**:
    - Description: Each Cluster must contain at least one host (computer) for guest Instances to run on. We will add the first host now. For a host to function in CloudStack, you must install hypervisor software on the host, assign an IP address to the host, and ensure the host is connected to the CloudStack management server. Give the host's DNS or IP address, the user name (usually root) and password, and any labels you use to categorize hosts.
    - Values:
      - Hostname/IP address: `10.10.17.10` (Replace with the actual hostname or IP address of your hypervisor host)
      - Username: `root`
      - Authentication Method: System SSH Key
  - **Primary Storage**:
    - Description: Each Cluster must contain one or more primary storage servers. We will add the first one now. Primary storage contains the disk volumes for all the Instances running on hosts in the cluster. Use any standards-compliant protocol that is supported by the underlying hypervisor.
    - Values:
      - Name: `primary-nfs-zone-homecloud`
      - Scope: `Zone`
      - Protocol: `nfs`
      - Server: `10.10.17.10` (Replace with the actual NFS server hostname or IP)
      - Path: `/export/primary` (Replace with the actual export path on the NFS server)
      - Provider: `DefaultPrimary`
  - **Secondary Storage**:
    - Description: Each Zone must have at least one NFS or secondary storage server. We will add the first one now. Secondary storage stores Instance Templates, ISO images, and Instance disk volume Snapshots. This server must be available to all hosts in the zone.
    - Values:
      - Provider: `nfs`
      - Name: `secondary-nfs-zone-homecloud`
      - Server: `10.10.17.10` (Replace with the actual NFS server hostname or IP)
      - Path: `/export/secondary` (Replace with the actual export path on the NFS server)
- **Launch and Enable Zone**
- **Register Templates**:
  - Description: Hosted on download.cloudstack.org, these templates can be easily registered directly within CloudStack. Simply click Register Template for the templates you wish to use.
  - Enable the following templates:
    - Ubuntu 24.04 LTS - `https://download.cloudstack.org/templates/cloud-images/ubuntu/ubuntu-24.04-server-cloudimg-amd64.img`
    - Debian GNU/Linux 12 (64-bit) - `https://download.cloudstack.org/templates/cloud-images/debian/debian-12-genericcloud-amd64.qcow2`
    - Rocky Linux 9 (KVM) - `https://download.cloudstack.org/templates/cloud-images/rockylinux/Rocky-9-GenericCloud.latest.x86_64.qcow2`
    - OpenSUSE 15.5 (KVM) - `https://download.cloudstack.org/templates/cloud-images/opensuse/openSUSE-Leap-15.5-Minimal-VM.x86_64-Cloud.qcow2`
    - Oracle Linux 9 (KVM) - `https://download.cloudstack.org/templates/cloud-images/oraclelinux/OL9U5_x86_64-kvm-b259.qcow2`
- **Post-Setup Tasks**:
  1. Add object storage server (for example, MinIO):
     - Access the CloudStack UI as an administrator.
     - Navigate to "Infrastructure > Object Storage".
     - Add your MinIO server details, including the endpoint URL, access key, secret key, and bucket name. For example:
       - Name: `minio-local`
       - Endpoint URL: `http://<your-minio-server-ip>:9000` (replace with your MinIO server address)
       - Access Key: `your-admin-username`
       - Secret Key: `your-admin-password`
       - Size (in GB): `1000` (or as needed)
     - Save the configuration and verify that CloudStack can connect to the MinIO server successfully.

  2. After adding a new host, ensure TLS is configured on the host by running the following command on the kvm host server (connect via SSH - `ssh cloud-admin@acs-node-0` - replace with your host address and user):

     ```shell
     sudo systemctl unmask libvirtd.socket libvirtd-ro.socket libvirtd-admin.socket libvirtd-tls.socket libvirtd-tcp.socket
     sudo systemctl stop libvirtd; sudo systemctl start libvirtd-tls.socket; sudo systemctl enable libvirtd-tls.socket
     sudo service cloudstack-agent restart
     sudo reboot now
     ```
