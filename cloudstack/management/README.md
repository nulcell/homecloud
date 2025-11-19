# CloudStack Management

## Global Configurations

### Access

#### Domain

- **metadata.allow.expose.domain**:
  - Description: If set to true, it allows the VM's domain to be seen in metadata.
  - Value: true

### Compute

#### VM

- **enable.additional.vm.configuration**:
  - Description: Allow additional arbitrary configuration to vm
  - Value: true
- **enable.dynamic.scale.vm**:
  - Description: Enables/Disables dynamically scaling a VM.
  - Value: false (default but you can enable it as needed)
- **system.vm.default.hypervisor**:
  - Description: Hypervisor type used to create system vm, valid values are: XenServer, KVM, VMware, Hyperv, VirtualBox, Parralels, BareMetal, Ovm, LXC, Any
  - Value: KVM
- **vm.allocation.algorithm**:
  - Description: Order in which hosts within a cluster will be considered for VM allocation. The value can be 'random', 'firstfit', 'userdispersing', 'userconcentratedpod_random', 'userconcentratedpod_firstfit', or 'firstfitleastconsumed'.
  - Value: `userdispersing`
- **vm.deployment.planner**:
  - Description: ['FirstFitPlanner', 'UserDispersingPlanner', 'UserConcentratedPodPlanner']: DeploymentPlanner heuristic that will be used for VM deployment.
  - Value: `UserDispersingPlanner`
- **vm.destroy.forcestop**:
  - Description: On destroy, force-stop takes this value.
  - Value: true
- **vm.display.ovf.properties**:
  - Description: Set display of VMs OVF properties as part of VM details.
  - Value: true
- **vm.password.length**:
  - Description: Specifies the length of a randomly generated password.
  - Value: 12
- **vm.userdata.max.length**:
  - Description: Max length of vm userdata after base64 encoding. Default is 32768 and maximum is 1048576
  - Value: 1048576

#### Kubernetes

- **cloud.kubernetes.cluster.experimental.features.enabled**:
  - Description: Enable experimental features for Kubernetes clusters.
  - Value: true

### Storage

#### Volume

- **destroy.root.volume.on.vm.destruction**:
  - Description: Destroys the VM's root volume when the VM is destroyed.
  - Value: true

#### Snapshot

- **snapshot.delta.max**:
  - Description: Max delta snapshots between two full snapshots. Only valid for KVM and XenServer.
  - Value: 32

### Network

- **network.throttling.rate**:
  - Description: Default data transfer rate in megabits per second allowed in network.
  - Value: 500

#### VPC

- **vpc.max.networks**:
  - Description: Maximum number of networks per vpc.
  - Value: 8
- **vpc.tier.name.prepend**:
  - Description: Whether to prepend the VPC name to the VPC tier network name.
  - Value: true
- **vpc.tier.name.prepend.delimiter**:
  - Description: Delimiter string to use between the VPC and the VPC tier name.
  - Value: `_`

### Hypervisor

#### KVM

- **enable.kvm.host.auto.enable.disable**:
  - Description: (KVM only) Enable Auto Disable/Enable KVM hosts in the cluster according to the hosts health check results.
  - Value: true
- **kvm.incremental.snapshot**:
  - Description: Whether differential snapshots are enabled for KVM or not. When this is enabled, all KVM snapshots will be incremental. Bear in mind that it will generate a new full snapshot when the snapshot chain reaches the limit defined in snapshot.delta.max.
  - Value: true

### Management Server

#### API

- **enable.ec2.api**:
  - Description: enable EC2 API on CloudStack.
  - Value: true
- **enable.s3.api**:
  - Description: enable Amazon S3 API on CloudStack.
  - Value: true

### System VMs

#### Console Proxy VM

- **consoleproxy.sslEnabled**:
  - Description: Enable SSL for console proxy.
  - Value: true

### Miscellaneous

#### Others

- **endpoint.url**:
  - Description: The endpoint URL for the management server.
  - Value: `http://acs-node-0:8080/client/api`  # Set to the management server or load balancer URL

## Zone Setup

- **Zone Type**:
  - Description: Type of zone to create.
  - Value: Core
  - Value Description: Core Zones are intended for Datacenter based deployments and allow the full range of Networking and other functionality in Apache CloudStack. Core Zones have a number of prerequisites and rely on the presence of shared storage and helper Instances.
- **Core Zone Type**:
  - Description: The specific type of Core Zone to create.
  - Value: Advanced (Security Groups Disabled)
  - Value Description: This is recommended and allows more sophisticated Network topologies. This Network model provides the most flexibility in defining guest Networks and providing custom Network offerings such as firewall, VPN, or load balancer support.
- **Zone Details**:
  - Description: A Zone is the largest organizational unit in CloudStack, and it typically corresponds to a single datacenter. Zones provide physical isolation and redundancy. A zone consists of one or more Pods (each of which contains hosts and primary storage servers) and a secondary storage server which is shared by all pods in the zone.
  - Values:
    - *Name: `zone-homecloud`
    - *IPv4 DNS1: `10.10.31.254` # Replace with your preferred DNS server
    - IPv4 DNS2: `8.8.8.8`  # Google Public DNS as secondary. You can also use `1.1.1.1` (Cloudflare) or another DNS server of your choice.
    - IPv6 DNS1: ``
    - IPv6 DNS2: ``
    - *Internal DNS 1: `10.10.31.254` # Replace with your internal DNS server (e.g., your router or local DNS server)
    - Internal DNS 2: ``
    - *Hypervisor: KVM
    - Default network domain for Isolated networks: `homecloud.internal`
    - Default guest CIDR for Isolated Networks: `10.0.0.0/24`
    - Enable local storage for User Instances: true
    - Enable local storage for System VMs: false
- **Network**:
  - **Physical Network**:
    - Description: When adding a Zone, you need to set up one or more physical networks. Each physical network can carry one or more types of traffic, with certain restrictions on how they may be combined. Add or remove one or more traffic types onto each physical network.
    - Values:
      - Network name: `Physical Network 1`
      - Isolation method: VLAN
      - Traffic types (traffic label):
        - Public (cloudbr0)
        - Management (cloudbr0)
        - Storage (cloudbr0)
        - Guest (cloudbr0)
  - **Public Traffic**:
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
      - Name: `pod-homecloud-0`
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
- **Add Resources**:
  - **Clusters**:
    - Description: Each Pod must contain one or more Clusters. We will add the first cluster now. A cluster provides a way to group hosts. The hosts in a cluster all have identical hardware, run the same hypervisor, are on the same subnet, and access the same shared storage. Each cluster consists of one or more hosts and one or more primary storage servers.
    - Values:
      - Name: `cluster-homecloud-0`
      - Arch: AMD 64 bit (x86_64)
  - **IP Address (Host)**:
    - Description: Each Cluster must contain at least one host (computer) for guest Instances to run on. We will add the first host now. For a host to function in CloudStack, you must install hypervisor software on the host, assign an IP address to the host, and ensure the host is connected to the CloudStack management server. Give the host's DNS or IP address, the user name (usually root) and password, and any labels you use to categorize hosts.
    - Values:
      - Hostname/IP address: `acs-node-0` (Replace with the actual hostname or IP address of your hypervisor host)
      - Username: `root`
      - Authentication Method: System SSH Key
  - **Primary Storage**:
    - Description: Each Cluster must contain one or more primary storage servers. We will add the first one now. Primary storage contains the disk volumes for all the Instances running on hosts in the cluster. Use any standards-compliant protocol that is supported by the underlying hypervisor.
    - Values:
      - Name: `primary-nfs-storage-zone-homecloud-0`
      - Scope: `Zone`
      - Protocol: `nfs`
      - Server: `acs-node-0` (Replace with the actual NFS server hostname or IP)
      - Path: `/export/primary` (Replace with the actual export path on the NFS server)
      - Provider: `DefaultPrimary`
  - **Secondary Storage**:
    - Description: Each Zone must have at least one NFS or secondary storage server. We will add the first one now. Secondary storage stores Instance Templates, ISO images, and Instance disk volume Snapshots. This server must be available to all hosts in the zone.
    - Values:
      - Provider: `nfs`
      - Name: `secondary-nfs-storage-zone-homecloud-0`
      - Server: `acs-node-0` (Replace with the actual NFS server hostname or IP)
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
  1. After adding a new host, ensure TLS is configured on the host by running the following command on the kvm host server (connect via SSH - `ssh cloud-admin@acs-node-0` - replace with your host address and user):

      ```shell
      sudo systemctl unmask libvirtd.socket libvirtd-ro.socket libvirtd-admin.socket libvirtd-tls.socket libvirtd-tcp.socket
      sudo systemctl stop libvirtd; sudo systemctl start libvirtd-tls.socket; sudo systemctl enable libvirtd-tls.socket
      sudo reboot now
      ```

  2. Add object storage server (for example, MinIO):
      - Access the CloudStack UI as an administrator.
      - Navigate to "Infrastructure > Object Storage".
      - Add your MinIO server details, including the endpoint URL, access key, secret key, and bucket name. For example:
        - Name: `minio-object-storage`
        - Endpoint URL: `http://<your-minio-server-ip>:9000` (replace with your MinIO server address)
        - Access Key: `your-admin-username`
        - Secret Key: `your-admin-password`
        - Size (in GB): `1000` (or as needed)
      - Save the configuration and verify that CloudStack can connect to the MinIO server successfully.

## Service Offerings

### Compute Offerings

- **Format**: `acs.comp.<feature>.<size>`
- **Naming conventions**:
  - **feature**:
  - `gen` - General Purpose
  - `mem` - Memory Optimized
  - `ssd` - Storage Optimized (i.e. with local NVME/SSD disks)
  - **size**:
  - `small`
  - `medium`
  - `large`
  - `xlarge`

| Offering Name | Description | vCPU | CPU Speed (MHz) | RAM (MB) | Network Bandwidth (Mbps) | GPU (vGPU) | Compute only disk offering | Storage type | Provisioning type | Write-cache type | QoS type | Root disk size (GB) | Encrypt |
|---------------|-------------|------|-----------------|----------|--------------------------|------------|---------------------------|--------------|-------------------|------------------|----------|--------------------|---------|
| `acs.comp.gen.small` | General Purpose Small | 1 | 4000 | 1024 | 200 | none | true | Shared | Thin | No disk cache | None | 10 | true |
| `acs.comp.gen.medium` | General Purpose Medium | 2 | 4000 | 2048 | 300 | none | true | Shared | Thin | No disk cache | None | 10 | true |
| `acs.comp.gen.large` | General Purpose Large | 4 | 4000 | 4096 | 500 | none | true | Shared | Thin | No disk cache | None | 10 | true |
| `acs.comp.gen.xlarge` | General Purpose xLarge | 8 | 4000 | 8192 | 500 | none | true | Shared | Thin | No disk cache | None | 10 | true |
| `acs.comp.mem.small` | Memory Optimized Small | 1 | 4000 | 2048 | 200 | none | true | Shared | Thin | No disk cache | None | 10 | true |
| `acs.comp.mem.medium` | Memory Optimized Medium | 2 | 4000 | 4096 | 300 | none | true | Shared | Thin | No disk cache | None | 10 | true |
| `acs.comp.mem.large` | Memory Optimized Large | 4 | 4000 | 8192 | 500 | none | true | Shared | Thin | No disk cache | None | 10 | true |
| `acs.comp.mem.xlarge` | Memory Optimized xLarge | 8 | 4000 | 16384 | 500 | none | true | Shared | Thin | No disk cache | None | 10 | true |
| `acs.comp.ssd.small` | Storage Optimized Small | 1 | 4000 | 1024 | 200 | none | false | Local | Thin | No disk cache | None | 50 | true |
| `acs.comp.ssd.medium` | Storage Optimized Medium | 2 | 4000 | 2048 | 300 | none | false | Local | Thin | No disk cache | None | 100 | true |
| `acs.comp.ssd.large` | Storage Optimized Large | 4 | 4000 | 4096 | 500 | none | false | Local | Thin | No disk cache | None | 200 | true |
| `acs.comp.ssd.xlarge` | Storage Optimized xLarge | 8 | 4000 | 8192 | 500 | none | false | Local | Thin | No disk cache | None | 400 | true |

- **General options across all offerings**:
  - **Offer HA**: true
  - **Dynamic scaling enabled**: false
  - **CPU cap**: false (no limit on CPU Speed, so it is always the max)
  - **Volatile**: false
  - **Deployment planner**: UserDispersingPlanner
  - **Public**: true
  - **Zone**: null (all zones)
  - **Purge Resources**: true

#### Create Service Offerings via CLI

```sh
cmk
create serviceoffering name="acs.comp.gen.small" displaytext="General Purpose Small" cpunumber=1 cpuspeed=4000 memory=1024 networkrate=200 offerha=true dynamicscalingenabled=false limitcpuuse=false isvolatile=false deploymentplanner="UserDispersingPlanner" ispublic=true storagetype="shared" provisioningtype="thin" diskofferingstrictness=true rootdisksize=10 encryptroot=true purgeresources=true
create serviceoffering name="acs.comp.gen.medium" displaytext="General Purpose Medium" cpunumber=2 cpuspeed=4000 memory=2048 networkrate=300 offerha=true dynamicscalingenabled=false limitcpuuse=false isvolatile=false deploymentplanner="UserDispersingPlanner" ispublic=true storagetype="shared" provisioningtype="thin" diskofferingstrictness=true rootdisksize=10 encryptroot=true purgeresources=true
create serviceoffering name="acs.comp.gen.large" displaytext="General Purpose Large" cpunumber=4 cpuspeed=4000 memory=4096 networkrate=500 offerha=true dynamicscalingenabled=false limitcpuuse=false isvolatile=false deploymentplanner="UserDispersingPlanner" ispublic=true storagetype="shared" provisioningtype="thin" diskofferingstrictness=true rootdisksize=10 encryptroot=true purgeresources=true
create serviceoffering name="acs.comp.gen.xlarge" displaytext="General Purpose xLarge" cpunumber=8 cpuspeed=4000 memory=8192 networkrate=500 offerha=true dynamicscalingenabled=false limitcpuuse=false isvolatile=false deploymentplanner="UserDispersingPlanner" ispublic=true storagetype="shared" provisioningtype="thin" diskofferingstrictness=true rootdisksize=10 encryptroot=true purgeresources=true
create serviceoffering name="acs.comp.mem.small" displaytext="Memory Optimized Small" cpunumber=1 cpuspeed=4000 memory=2048 networkrate=200 offerha=true dynamicscalingenabled=false limitcpuuse=false isvolatile=false deploymentplanner="UserDispersingPlanner" ispublic=true storagetype="shared" provisioningtype="thin" diskofferingstrictness=true rootdisksize=10 encryptroot=true purgeresources=true
create serviceoffering name="acs.comp.mem.medium" displaytext="Memory Optimized Medium" cpunumber=2 cpuspeed=4000 memory=4096 networkrate=300 offerha=true dynamicscalingenabled=false limitcpuuse=false isvolatile=false deploymentplanner="UserDispersingPlanner" ispublic=true storagetype="shared" provisioningtype="thin" diskofferingstrictness=true rootdisksize=10 encryptroot=true purgeresources=true
create serviceoffering name="acs.comp.mem.large" displaytext="Memory Optimized Large" cpunumber=4 cpuspeed=4000 memory=8192 networkrate=500 offerha=true dynamicscalingenabled=false limitcpuuse=false isvolatile=false deploymentplanner="UserDispersingPlanner" ispublic=true storagetype="shared" provisioningtype="thin" diskofferingstrictness=true rootdisksize=10 encryptroot=true purgeresources=true
create serviceoffering name="acs.comp.mem.xlarge" displaytext="Memory Optimized xLarge" cpunumber=8 cpuspeed=4000 memory=16384 networkrate=500 offerha=true dynamicscalingenabled=false limitcpuuse=false isvolatile=false deploymentplanner="UserDispersingPlanner" ispublic=true storagetype="shared" provisioningtype="thin" diskofferingstrictness=true rootdisksize=10 encryptroot=true purgeresources=true
create serviceoffering name="acs.comp.ssd.small" displaytext="Storage Optimized Small" cpunumber=1 cpuspeed=4000 memory=1024 networkrate=200 offerha=false dynamicscalingenabled=false limitcpuuse=false isvolatile=false deploymentplanner="UserDispersingPlanner" ispublic=true storagetype="local" provisioningtype="thin" diskofferingstrictness=false rootdisksize=50 encryptroot=true purgeresources=true
create serviceoffering name="acs.comp.ssd.medium" displaytext="Storage Optimized Medium" cpunumber=2 cpuspeed=4000 memory=2048 networkrate=300 offerha=false dynamicscalingenabled=false limitcpuuse=false isvolatile=false deploymentplanner="UserDispersingPlanner" ispublic=true storagetype="local" provisioningtype="thin" diskofferingstrictness=false rootdisksize=100 encryptroot=true purgeresources=true
create serviceoffering name="acs.comp.ssd.large" displaytext="Storage Optimized Large" cpunumber=4 cpuspeed=4000 memory=4096 networkrate=500 offerha=false dynamicscalingenabled=false limitcpuuse=false isvolatile=false deploymentplanner="UserDispersingPlanner" ispublic=true storagetype="local" provisioningtype="thin" diskofferingstrictness=false rootdisksize=200 encryptroot=true purgeresources=true
create serviceoffering name="acs.comp.ssd.xlarge" displaytext="Storage Optimized xLarge" cpunumber=8 cpuspeed=4000 memory=8192 networkrate=500 offerha=false dynamicscalingenabled=false limitcpuuse=false isvolatile=false deploymentplanner="UserDispersingPlanner" ispublic=true storagetype="local" provisioningtype="thin" diskofferingstrictness=false rootdisksize=400 encryptroot=true purgeresources=true
```
  
### Disk Offerings

- **Format**: `acs.disk.<type>.<size>`
- **Naming conventions**:
  - **type**:
    - `shared` - Shared Storage
    - `local` - Local Storage (i.e. with local NVME/SSD disks)
  - **size**:
    - `custom` - Custom size defined at volume creation time
    - `small` - 10 GB
    - `medium` - 50 GB
    - `large` - 100 GB
    - `xlarge` - 200 GB

| Offering Name | Description | Storage type | Provisioning type | Encrypt | Disk size strictness | Custom disk size | Size (GB) | QoS type | Write-cache Type | Public | Zone |
|---------------|-------------|--------------|-------------------|---------|----------------------|------------------|-----------|----------|------------------|--------|------|
| `acs.disk.shared.custom` | Shared Storage Custom Size Disk | Shared | Thin | true | false | true | null | None | No Disk Cache | true | null |
| `acs.disk.local.custom` | Local Storage Custom Size Disk | Local | Thin | true | false | true | null | None | No Disk Cache | true | null |
| `acs.disk.shared.small` | Shared Storage Small Disk | Shared | Thin | true | false | false | 10 | None | No Disk Cache | true | null |
| `acs.disk.shared.medium` | Shared Storage Medium Disk | Shared | Thin | true | false | false | 50 | None | No Disk Cache | true | null |
| `acs.disk.shared.large` | Shared Storage Large Disk | Shared | Thin | true |false | false | 100 | None | No Disk Cache | true | null |
| `acs.disk.shared.xlarge` | Shared Storage XLarge Disk | Shared | Thin | true | false | false | 200 | None | No Disk Cache | true | null |
| `acs.disk.local.small` | Local Storage Small Disk | Local | Thin | true | false | false | 10 | None | No Disk Cache | true | null |
| `acs.disk.local.medium` | Local Storage Medium Disk | Local | Thin | true | false | false | 50 | None | No Disk Cache | true | null |
| `acs.disk.local.large` | Local Storage Large Disk | Local | Thin | true | false | false | 100 | None | No Disk Cache | true | null |
| `acs.disk.local.xlarge` | Local Storage xLarge Disk | Local | Thin | true | false | false | 200 | None | No Disk Cache | true | null |

#### Create Disk Offerings via CLI

```sh
cmk
create diskoffering name="acs.disk.shared.custom" displaytext="Shared Storage Custom Size Disk" storagetype="shared" customdisksize=true disksizeStrictness=false encrypt=true ispublic=true qostype="None" cachemode="none" customized=true
create diskoffering name="acs.disk.local.custom" displaytext="Local Storage Custom Size Disk" storagetype="local" customdisksize=true disksizeStrictness=false encrypt=true ispublic=true qostype="None" cachemode="none" customized=true
create diskoffering name="acs.disk.shared.small" displaytext="Shared Storage Small Disk" storagetype="shared" disksize=10 customdisksize=false disksizeStrictness=false encrypt=true ispublic=true qostype="None" cachemode="none"
create diskoffering name="acs.disk.shared.medium" displaytext="Shared Storage Medium Disk" storagetype="shared" disksize=50 customdisksize=false disksizeStrictness=false encrypt=true ispublic=true qostype="None" cachemode="none"
create diskoffering name="acs.disk.shared.large" displaytext="Shared Storage Large Disk" storagetype="shared" disksize=100 customdisksize=false disksizeStrictness=false encrypt=true ispublic=true qostype="None" cachemode="none"
create diskoffering name="acs.disk.shared.xlarge" displaytext="Shared Storage XLarge Disk" storagetype="shared" disksize=200 customdisksize=false disksizeStrictness=false encrypt=true ispublic=true qostype="None" cachemode="none"
create diskoffering name="acs.disk.local.small" displaytext="Local Storage Small Disk" storagetype="local" disksize=10 customdisksize=false disksizeStrictness=false encrypt=true ispublic=true qostype="None" cachemode="none"
create diskoffering name="acs.disk.local.medium" displaytext="Local Storage Medium Disk" storagetype="local" disksize=50 customdisksize=false disksizeStrictness=false encrypt=true ispublic=true qostype="None" cachemode="none"
create diskoffering name="acs.disk.local.large" displaytext="Local Storage Large Disk" storagetype="local" disksize=100 customdisksize=false disksizeStrictness=false encrypt=true ispublic=true qostype="None" cachemode="none"
create diskoffering name="acs.disk.local.xlarge" displaytext="Local Storage xLarge Disk" storagetype="local" disksize=200 customdisksize=false disksizeStrictness=false encrypt=true ispublic=true qostype="None" cachemode="none"
```  

### Network Offerings

- **Format**: `acs.net.<type>.<feature>`
- **Naming conventions**:
  - **type**:
    - `isolated` - Isolated Network
    - `vpc` - Isolated VPC Network
    - `shared` - Shared Network
    - `l2` - L2 Network (not covered yet)

| Offering Name | Description | Network rate (Mb/s) | Guest Type | Internet protocol | Specify VLAN | Persistent | VPC | Provider | Network Mode | Promiscuous mode | Forged transmits | MAC address changes | MAC learning | Supported services (Service Provider) | Load balancer type | Compute Offering | Redundant router | Supported source NAT type | Supports auto scaling | Conserve mode | Default egress policy | Public | Zone |
|---------------|-------------|---------------------|------------|-------------------|--------------|------------|-----|----------|--------------|------------------|------------------|--------------------|--------------|---------------------------------------|--------------------|------------------|------------------|--------------------------|-----------------------|---------------|-----------------------|--------|------|
| `acs.net.shared.core` | Shared Network with Virtual Router | 500 | Shared | N/A | false | N/A | N/A | NONE | NATTED | None | None | None | None | Vpn(VirtualRouter), Dhcp(VirtualRouter), Dns(VirtualRouter), Firewall(VirtualRouter), Lb(VirtualRouter), UserData (VirtualRouter) , SourceNat(VirtualRouter), StaticNat(VirtualRouter), PortForwarding(VirtualRouter) | N/A | System Offering for Software Router | true | Per Account NAT | true | true | allow | true | null |
| `acs.net.shared.core-vlan` | Shared Network with Virtual Router and VLAN specified | 500 | Shared | N/A | true | N/A | N/A | NONE | NATTED | None | None | None | None | Vpn(VirtualRouter), Dhcp(VirtualRouter), Dns(VirtualRouter), Firewall(VirtualRouter), Lb(VirtualRouter), UserData (VirtualRouter) , SourceNat(VirtualRouter), StaticNat(VirtualRouter), PortForwarding(VirtualRouter) | N/A | System Offering for Software Router | true | Per Account NAT | true | true | allow | true | null |
| `acs.net.shared.security-group` | Shared Network with Security Groups and Virtual Router | 500 | Shared | N/A | false | N/A | N/A | NONE | NATTED | None | None | None | None | Vpn(VirtualRouter), Dhcp(VirtualRouter), Dns(VirtualRouter), Firewall(VirtualRouter), Lb(VirtualRouter), UserData (VirtualRouter) , SourceNat(VirtualRouter), StaticNat(VirtualRouter), PortForwarding(VirtualRouter), SecurityGroup(SecurityGroupProvider) | N/A | System Offering for Software Router | true | Per Account NAT | true | true | allow | true | null |
| `acs.net.shared.security-group-vlan` | Shared Network with Security Groups, Virtual Router and VLAN specified | 500 | Shared | N/A | true | N/A | N/A | NONE | NATTED | None | None | None | None | Vpn(VirtualRouter), Dhcp(VirtualRouter), Dns(VirtualRouter), Firewall(VirtualRouter), Lb(VirtualRouter), UserData (VirtualRouter) , SourceNat(VirtualRouter), StaticNat(VirtualRouter), PortForwarding(VirtualRouter), SecurityGroup(SecurityGroupProvider) | N/A | System Offering for Software Router | true | Per Account NAT | true | true | allow | true | null |
| `acs.net.shared.core-config-drive` | Shared Network with Config Drive and Virtual Router | 500 | Shared | N/A | false | N/A | N/A | NONE | NATTED | None | None | None | None | Vpn(VirtualRouter), Dhcp(ConfigDrive), Dns(ConfigDrive), Firewall(VirtualRouter), Lb(VirtualRouter), UserData (ConfigDrive) , SourceNat(VirtualRouter), StaticNat(VirtualRouter), PortForwarding(VirtualRouter) | N/A | System Offering for Software Router | true | Per Account NAT | true | true | allow | true | null |
| `acs.net.shared.config-drive-security-group` | Shared Network with Config Drive, Security Groups and Virtual Router | 500 | Shared | N/A | false | N/A | N/A | NONE | NATTED | | None | None | None | Vpn(VirtualRouter), Dhcp(ConfigDrive), Dns(ConfigDrive), Firewall(VirtualRouter), Lb(VirtualRouter), UserData (ConfigDrive) , SourceNat(VirtualRouter), StaticNat(VirtualRouter), PortForwarding(VirtualRouter), SecurityGroup(SecurityGroupProvider) | N/A | System Offering for Software Router | true | Per Account NAT | true | true | allow | true | null |
| `acs.net.isolated.core` | Isolated Network with Virtual Router | 500 | Isolated | IPv4 | false | true | false | NONE | NATTED | None | None | None | None | Vpn(VirtualRouter), Dhcp(VirtualRouter), Dns(VirtualRouter), Firewall(VirtualRouter), Lb(VirtualRouter), UserData (VirtualRouter) , SourceNat(VirtualRouter), StaticNat(VirtualRouter), PortForwarding(VirtualRouter) | N/A | System Offering for Software Router | true | Per Account NAT | true | true | allow | true | null |
| `acs.net.isolated.core-config-drive` | Isolated Network with Config Drive and Virtual Router | 500 | Isolated | IPv4 | false | true | false | NONE | NATTED | None | None | None | None | Vpn(VirtualRouter), Dhcp(ConfigDrive), Dns(ConfigDrive), Firewall(VirtualRouter), Lb(VirtualRouter), UserData (ConfigDrive) , SourceNat(VirtualRouter), StaticNat(VirtualRouter), PortForwarding(VirtualRouter) | N/A | System Offering for Software Router | true | Per Account NAT | true | true | allow | true | null |
| `acs.net.vpc.public` | VPC Network with Public Load Balancer | 500 | Isolated | IPv4 | false | true | true | NONE | NATTED | None | None | None | None | Vpn(VpcVirtualRouter), Dhcp(VpcVirtualRouter), Dns(VpcVirtualRouter), Lb(VpcVirtualRouter), UserData (VpcVirtualRouter) , SourceNat(VpcVirtualRouter), StaticNat(VpcVirtualRouter), PortForwarding(VpcVirtualRouter), NetworkACL(VpcVirtualRouter) | Public LB | System Offering for VPC Router (would just use VPC Virtual Router) | N/A | Per Account NAT | true | true | allow | true | null |
| `acs.net.vpc.public-config-drive` | VPC Network with Config Drive and Public Load Balancer | 500 | Isolated | IPv4 | false | true | true | NONE | NATTED | None | None | None | None | Vpn(VpcVirtualRouter), Dhcp(ConfigDrive), Dns(ConfigDrive), Lb(VpcVirtualRouter), UserData (ConfigDrive) , SourceNat(VpcVirtualRouter), StaticNat(VpcVirtualRouter), PortForwarding(VpcVirtualRouter), NetworkACL(VpcVirtualRouter) | Public LB | System Offering for VPC Router (would just use VPC Virtual Router) | N/A | Per Account NAT | true | true | allow | true | null |
| `acs.net.vpc.internal` | VPC Network with Internal Load Balancer | 500 | Isolated | IPv4 | false | true | true | NONE | NATTED | None | None | None | None | Vpn(VpcVirtualRouter), Dhcp(VpcVirtualRouter), Dns(VpcVirtualRouter), Lb(VpcVirtualRouter), UserData (VpcVirtualRouter) , SourceNat(VpcVirtualRouter), StaticNat(VpcVirtualRouter), PortForwarding(VpcVirtualRouter), NetworkACL(VpcVirtualRouter) | Internal LB | System Offering for VPC Router (would just use VPC Virtual Router) | N/A | Per Account NAT | true | true | allow | true | null |
| `acs.net.vpc.internal-config-drive` | VPC Network with Config Drive and Internal Load Balancer | 500 | Isolated | IPv4 | false | true | true | NONE | NATTED | None | None | None | None | Vpn(VpcVirtualRouter), Dhcp(ConfigDrive), Dns(ConfigDrive), Lb(VpcVirtualRouter), UserData (ConfigDrive) , SourceNat(VpcVirtualRouter), StaticNat(VpcVirtualRouter), PortForwarding(VpcVirtualRouter), NetworkACL(VpcVirtualRouter) | Internal LB | System Offering for VPC Router (would just use VPC Virtual Router) | N/A | Per Account NAT | true | true | allow | true | null |
| `acs.net.vpc.internal-lb-vm` | VPC Network with Internal Load Balancer (using Internal LB VM) | 500 | Isolated | IPv4 | false | true | true | NONE | NATTED | None | None | None | None | Vpn(VpcVirtualRouter), Dhcp(VpcVirtualRouter), Dns(VpcVirtualRouter), Lb(InternalLbVm), UserData (VpcVirtualRouter) , SourceNat(VpcVirtualRouter), StaticNat(VpcVirtualRouter), PortForwarding(VpcVirtualRouter), NetworkACL(VpcVirtualRouter) | Internal LB VM | System Offering for VPC Router (would just use VPC Virtual Router) | N/A | Per Account NAT | true | true | allow | true | null |

#### Create Network Offerings via CLI

```sh
cmk
create networkoffering name="acs.net.shared.core" displaytext="Shared Network with Virtual Router" guestiptype="Shared" traffictype="Guest" networkrate=500 specifyvlan=false conservemode=true egressdefaultpolicy=true ispublic=true enable=true specifyipranges=true ispersistent=false forvpc=false supportedservices="Vpn,Dhcp,Dns,Firewall,Lb,UserData,SourceNat,StaticNat,PortForwarding" serviceproviderlist[0].service="Vpn" serviceproviderlist[0].provider="VirtualRouter" serviceproviderlist[1].service="Dhcp" serviceproviderlist[1].provider="VirtualRouter" serviceproviderlist[2].service="Dns" serviceproviderlist[2].provider="VirtualRouter" serviceproviderlist[3].service="Firewall" serviceproviderlist[3].provider="VirtualRouter" serviceproviderlist[4].service="Lb" serviceproviderlist[4].provider="VirtualRouter" serviceproviderlist[5].service="UserData" serviceproviderlist[5].provider="VirtualRouter" serviceproviderlist[6].service="SourceNat" serviceproviderlist[6].provider="VirtualRouter" serviceproviderlist[7].service="StaticNat" serviceproviderlist[7].provider="VirtualRouter" serviceproviderlist[8].service="PortForwarding" serviceproviderlist[8].provider="VirtualRouter" serviceCapabilityList[0].service="SourceNat" serviceCapabilityList[0].capabilitytype="RedundantRouter" serviceCapabilityList[0].capabilityvalue="true"
create networkoffering name="acs.net.shared.core-vlan" displaytext="Shared Network with Virtual Router and VLAN specified" guestiptype="Shared" traffictype="Guest" networkrate=500 specifyvlan=true conservemode=true egressdefaultpolicy=true ispublic=true enable=true specifyipranges=true ispersistent=false forvpc=false supportedservices="Vpn,Dhcp,Dns,Firewall,Lb,UserData,SourceNat,StaticNat,PortForwarding" serviceproviderlist[0].service="Vpn" serviceproviderlist[0].provider="VirtualRouter" serviceproviderlist[1].service="Dhcp" serviceproviderlist[1].provider="VirtualRouter" serviceproviderlist[2].service="Dns" serviceproviderlist[2].provider="VirtualRouter" serviceproviderlist[3].service="Firewall" serviceproviderlist[3].provider="VirtualRouter" serviceproviderlist[4].service="Lb" serviceproviderlist[4].provider="VirtualRouter" serviceproviderlist[5].service="UserData" serviceproviderlist[5].provider="VirtualRouter" serviceproviderlist[6].service="SourceNat" serviceproviderlist[6].provider="VirtualRouter" serviceproviderlist[7].service="StaticNat" serviceproviderlist[7].provider="VirtualRouter" serviceproviderlist[8].service="PortForwarding" serviceproviderlist[8].provider="VirtualRouter" serviceCapabilityList[0].service="SourceNat" serviceCapabilityList[0].capabilitytype="RedundantRouter" serviceCapabilityList[0].capabilityvalue="true"
create networkoffering name="acs.net.shared.security-group" displaytext="Shared Network with Security Groups and Virtual Router" guestiptype="Shared" traffictype="Guest" networkrate=500 specifyvlan=false conservemode=true egressdefaultpolicy=true ispublic=true enable=true specifyipranges=true ispersistent=false forvpc=false supportedservices="Vpn,Dhcp,Dns,Firewall,Lb,UserData,SourceNat,StaticNat,PortForwarding,SecurityGroup" serviceproviderlist[0].service="Vpn" serviceproviderlist[0].provider="VirtualRouter" serviceproviderlist[1].service="Dhcp" serviceproviderlist[1].provider="VirtualRouter" serviceproviderlist[2].service="Dns" serviceproviderlist[2].provider="VirtualRouter" serviceproviderlist[3].service="Firewall" serviceproviderlist[3].provider="VirtualRouter" serviceproviderlist[4].service="Lb" serviceproviderlist[4].provider="VirtualRouter" serviceproviderlist[5].service="UserData" serviceproviderlist[5].provider="VirtualRouter" serviceproviderlist[6].service="SourceNat" serviceproviderlist[6].provider="VirtualRouter" serviceproviderlist[7].service="StaticNat" serviceproviderlist[7].provider="VirtualRouter" serviceproviderlist[8].service="PortForwarding" serviceproviderlist[8].provider="VirtualRouter" serviceproviderlist[9].service="SecurityGroup" serviceproviderlist[9].provider="SecurityGroupProvider" serviceCapabilityList[0].service="SourceNat" serviceCapabilityList[0].capabilitytype="RedundantRouter" serviceCapabilityList[0].capabilityvalue="true"
create networkoffering name="acs.net.shared.security-group-vlan" displaytext="Shared Network with Security Groups, Virtual Router and VLAN specified" guestiptype="Shared" traffictype="Guest" networkrate=500 specifyvlan=true conservemode=true egressdefaultpolicy=true ispublic=true enable=true specifyipranges=true ispersistent=false forvpc=false supportedservices="Vpn,Dhcp,Dns,Firewall,Lb,UserData,SourceNat,StaticNat,PortForwarding,SecurityGroup" serviceproviderlist[0].service="Vpn" serviceproviderlist[0].provider="VirtualRouter" serviceproviderlist[1].service="Dhcp" serviceproviderlist[1].provider="VirtualRouter" serviceproviderlist[2].service="Dns" serviceproviderlist[2].provider="VirtualRouter" serviceproviderlist[3].service="Firewall" serviceproviderlist[3].provider="VirtualRouter" serviceproviderlist[4].service="Lb" serviceproviderlist[4].provider="VirtualRouter" serviceproviderlist[5].service="UserData" serviceproviderlist[5].provider="VirtualRouter" serviceproviderlist[6].service="SourceNat" serviceproviderlist[6].provider="VirtualRouter" serviceproviderlist[7].service="StaticNat" serviceproviderlist[7].provider="VirtualRouter" serviceproviderlist[8].service="PortForwarding" serviceproviderlist[8].provider="VirtualRouter" serviceproviderlist[9].service="SecurityGroup" serviceproviderlist[9].provider="SecurityGroupProvider" serviceCapabilityList[0].service="SourceNat" serviceCapabilityList[0].capabilitytype="RedundantRouter" serviceCapabilityList[0].capabilityvalue="true"
create networkoffering name="acs.net.shared.core-config-drive" displaytext="Shared Network with Config Drive and Virtual Router" guestiptype="Shared" traffictype="Guest" networkrate=500 specifyvlan=false conservemode=true egressdefaultpolicy=true ispublic=true enable=true specifyipranges=true ispersistent=false forvpc=false supportedservices="Vpn,Dhcp,Dns,Firewall,Lb,UserData,SourceNat,StaticNat,PortForwarding" serviceproviderlist[0].service="Vpn" serviceproviderlist[0].provider="VirtualRouter" serviceproviderlist[1].service="Dhcp" serviceproviderlist[1].provider="ConfigDrive" serviceproviderlist[2].service="Dns" serviceproviderlist[2].provider="ConfigDrive" serviceproviderlist[3].service="Firewall" serviceproviderlist[3].provider="VirtualRouter" serviceproviderlist[4].service="Lb" serviceproviderlist[4].provider="VirtualRouter" serviceproviderlist[5].service="UserData" serviceproviderlist[5].provider="ConfigDrive" serviceproviderlist[6].service="SourceNat" serviceproviderlist[6].provider="VirtualRouter" serviceproviderlist[7].service="StaticNat" serviceproviderlist[7].provider="VirtualRouter" serviceproviderlist[8].service="PortForwarding" serviceproviderlist[8].provider="VirtualRouter" serviceCapabilityList[0].service="SourceNat" serviceCapabilityList[0].capabilitytype="RedundantRouter" serviceCapabilityList[0].capabilityvalue="true"
create networkoffering name="acs.net.shared.config-drive-security-group" displaytext="Shared Network with Config Drive, Security Groups and Virtual Router" guestiptype="Shared" traffictype="Guest" networkrate=500 specifyvlan=false conservemode=true egressdefaultpolicy=true ispublic=true enable=true specifyipranges=true ispersistent=false forvpc=false supportedservices="Vpn,Dhcp,Dns,Firewall,Lb,UserData,SourceNat,StaticNat,PortForwarding,SecurityGroup" serviceproviderlist[0].service="Vpn" serviceproviderlist[0].provider="VirtualRouter" serviceproviderlist[1].service="Dhcp" serviceproviderlist[1].provider="ConfigDrive" serviceproviderlist[2].service="Dns" serviceproviderlist[2].provider="ConfigDrive" serviceproviderlist[3].service="Firewall" serviceproviderlist[3].provider="VirtualRouter" serviceproviderlist[4].service="Lb" serviceproviderlist[4].provider="VirtualRouter" serviceproviderlist[5].service="UserData" serviceproviderlist[5].provider="ConfigDrive" serviceproviderlist[6].service="SourceNat" serviceproviderlist[6].provider="VirtualRouter" serviceproviderlist[7].service="StaticNat" serviceproviderlist[7].provider="VirtualRouter" serviceproviderlist[8].service="PortForwarding" serviceproviderlist[8].provider="VirtualRouter" serviceproviderlist[9].service="SecurityGroup" serviceproviderlist[9].provider="SecurityGroupProvider" serviceCapabilityList[0].service="SourceNat" serviceCapabilityList[0].capabilitytype="RedundantRouter" serviceCapabilityList[0].capabilityvalue="true"


# Isolated Network offerings
create networkoffering name="acs.net.isolated.core" displaytext="Isolated Network with Virtual Router" guestiptype="Isolated" traffictype="Guest" networkrate=500 specifyvlan=false ispersistent=true forvpc=false networkmode="NATTED" conservemode=true egressdefaultpolicy=true ispublic=true enable=true specifyipranges=false supportedservices="Vpn,Dhcp,Dns,Firewall,Lb,UserData,SourceNat,StaticNat,PortForwarding" serviceproviderlist[0].service="Vpn" serviceproviderlist[0].provider="VirtualRouter" serviceproviderlist[1].service="Dhcp" serviceproviderlist[1].provider="VirtualRouter" serviceproviderlist[2].service="Dns" serviceproviderlist[2].provider="VirtualRouter" serviceproviderlist[3].service="Firewall" serviceproviderlist[3].provider="VirtualRouter" serviceproviderlist[4].service="Lb" serviceproviderlist[4].provider="VirtualRouter" serviceproviderlist[5].service="UserData" serviceproviderlist[5].provider="VirtualRouter" serviceproviderlist[6].service="SourceNat" serviceproviderlist[6].provider="VirtualRouter" serviceproviderlist[7].service="StaticNat" serviceproviderlist[7].provider="VirtualRouter" serviceproviderlist[8].service="PortForwarding" serviceproviderlist[8].provider="VirtualRouter" serviceCapabilityList[0].service="SourceNat" serviceCapabilityList[0].capabilitytype="RedundantRouter" serviceCapabilityList[0].capabilityvalue="true"
create networkoffering name="acs.net.isolated.core-config-drive" displaytext="Isolated Network with Config Drive and Virtual Router" guestiptype="Isolated" traffictype="Guest" networkrate=500 specifyvlan=false ispersistent=true forvpc=false networkmode="NATTED" conservemode=true egressdefaultpolicy=true ispublic=true enable=true specifyipranges=false supportedservices="Vpn,Dhcp,Dns,Firewall,Lb,UserData,SourceNat,StaticNat,PortForwarding" serviceproviderlist[0].service="Vpn" serviceproviderlist[0].provider="VirtualRouter" serviceproviderlist[1].service="Dhcp" serviceproviderlist[1].provider="ConfigDrive" serviceproviderlist[2].service="Dns" serviceproviderlist[2].provider="ConfigDrive" serviceproviderlist[3].service="Firewall" serviceproviderlist[3].provider="VirtualRouter" serviceproviderlist[4].service="Lb" serviceproviderlist[4].provider="VirtualRouter" serviceproviderlist[5].service="UserData" serviceproviderlist[5].provider="ConfigDrive" serviceproviderlist[6].service="SourceNat" serviceproviderlist[6].provider="VirtualRouter" serviceproviderlist[7].service="StaticNat" serviceproviderlist[7].provider="VirtualRouter" serviceproviderlist[8].service="PortForwarding" serviceproviderlist[8].provider="VirtualRouter" serviceCapabilityList[0].service="SourceNat" serviceCapabilityList[0].capabilitytype="RedundantRouter" serviceCapabilityList[0].capabilityvalue="true"


# VPC Network offerings
create networkoffering name="acs.net.vpc.public" displaytext="VPC Network with Public Load Balancer" guestiptype="Isolated" traffictype="Guest" networkrate=500 specifyvlan=false ispersistent=true forvpc=true networkmode="NATTED" conservemode=true egressdefaultpolicy=true ispublic=true enable=true specifyipranges=false supportedservices="Vpn,Dhcp,Dns,Lb,UserData,SourceNat,StaticNat,PortForwarding,NetworkACL" serviceproviderlist[0].service="Vpn" serviceproviderlist[0].provider="VpcVirtualRouter" serviceproviderlist[1].service="Dhcp" serviceproviderlist[1].provider="VpcVirtualRouter" serviceproviderlist[2].service="Dns" serviceproviderlist[2].provider="VpcVirtualRouter" serviceproviderlist[3].service="Lb" serviceproviderlist[3].provider="VpcVirtualRouter" serviceproviderlist[4].service="UserData" serviceproviderlist[4].provider="VpcVirtualRouter" serviceproviderlist[5].service="SourceNat" serviceproviderlist[5].provider="VpcVirtualRouter" serviceproviderlist[6].service="StaticNat" serviceproviderlist[6].provider="VpcVirtualRouter" serviceproviderlist[7].service="PortForwarding" serviceproviderlist[7].provider="VpcVirtualRouter" serviceproviderlist[8].service="NetworkACL" serviceproviderlist[8].provider="VpcVirtualRouter" details.publiclbprovider="VpcVirtualRouter"
create networkoffering name="acs.net.vpc.public-config-drive" displaytext="VPC Network with Config Drive and Public Load Balancer" guestiptype="Isolated" traffictype="Guest" networkrate=500 specifyvlan=false ispersistent=true forvpc=true networkmode="NATTED" conservemode=true egressdefaultpolicy=true ispublic=true enable=true specifyipranges=false supportedservices="Vpn,Dhcp,Dns,Lb,UserData,SourceNat,StaticNat,PortForwarding,NetworkACL" serviceproviderlist[0].service="Vpn" serviceproviderlist[0].provider="VpcVirtualRouter" serviceproviderlist[1].service="Dhcp" serviceproviderlist[1].provider="ConfigDrive" serviceproviderlist[2].service="Dns" serviceproviderlist[2].provider="ConfigDrive" serviceproviderlist[3].service="Lb" serviceproviderlist[3].provider="VpcVirtualRouter" serviceproviderlist[4].service="UserData" serviceproviderlist[4].provider="ConfigDrive" serviceproviderlist[5].service="SourceNat" serviceproviderlist[5].provider="VpcVirtualRouter" serviceproviderlist[6].service="StaticNat" serviceproviderlist[6].provider="VpcVirtualRouter" serviceproviderlist[7].service="PortForwarding" serviceproviderlist[7].provider="VpcVirtualRouter" serviceproviderlist[8].service="NetworkACL" serviceproviderlist[8].provider="VpcVirtualRouter" details.publiclbprovider="VpcVirtualRouter"
create networkoffering name="acs.net.vpc.internal" displaytext="VPC Network with Internal Load Balancer" guestiptype="Isolated" traffictype="Guest" networkrate=500 specifyvlan=false ispersistent=true forvpc=true networkmode="NATTED" conservemode=true egressdefaultpolicy=true ispublic=true enable=true specifyipranges=false supportedservices="Vpn,Dhcp,Dns,Lb,UserData,SourceNat,StaticNat,PortForwarding,NetworkACL" serviceproviderlist[0].service="Vpn" serviceproviderlist[0].provider="VpcVirtualRouter" serviceproviderlist[1].service="Dhcp" serviceproviderlist[1].provider="VpcVirtualRouter" serviceproviderlist[2].service="Dns" serviceproviderlist[2].provider="VpcVirtualRouter" serviceproviderlist[3].service="Lb" serviceproviderlist[3].provider="VpcVirtualRouter" serviceproviderlist[4].service="UserData" serviceproviderlist[4].provider="VpcVirtualRouter" serviceproviderlist[5].service="SourceNat" serviceproviderlist[5].provider="VpcVirtualRouter" serviceproviderlist[6].service="StaticNat" serviceproviderlist[6].provider="VpcVirtualRouter" serviceproviderlist[7].service="PortForwarding" serviceproviderlist[7].provider="VpcVirtualRouter" serviceproviderlist[8].service="NetworkACL" serviceproviderlist[8].provider="VpcVirtualRouter" details.internallbprovider="VpcVirtualRouter"
create networkoffering name="acs.net.vpc.internal-config-drive" displaytext="VPC Network with Config Drive and Internal Load Balancer" guestiptype="Isolated" traffictype="Guest" networkrate=500 specifyvlan=false ispersistent=true forvpc=true networkmode="NATTED" conservemode=true egressdefaultpolicy=true ispublic=true enable=true specifyipranges=false supportedservices="Vpn,Dhcp,Dns,Lb,UserData,SourceNat,StaticNat,PortForwarding,NetworkACL" serviceproviderlist[0].service="Vpn" serviceproviderlist[0].provider="VpcVirtualRouter" serviceproviderlist[1].service="Dhcp" serviceproviderlist[1].provider="ConfigDrive" serviceproviderlist[2].service="Dns" serviceproviderlist[2].provider="ConfigDrive" serviceproviderlist[3].service="Lb" serviceproviderlist[3].provider="VpcVirtualRouter" serviceproviderlist[4].service="UserData" serviceproviderlist[4].provider="ConfigDrive" serviceproviderlist[5].service="SourceNat" serviceproviderlist[5].provider="VpcVirtualRouter" serviceproviderlist[6].service="StaticNat" serviceproviderlist[6].provider="VpcVirtualRouter" serviceproviderlist[7].service="PortForwarding" serviceproviderlist[7].provider="VpcVirtualRouter" serviceproviderlist[8].service="NetworkACL" serviceproviderlist[8].provider="VpcVirtualRouter" details.internallbprovider="VpcVirtualRouter"
create networkoffering name="acs.net.vpc.internal-lb-vm" displaytext="VPC Network with Internal Load Balancer (using Internal LB VM)" guestiptype="Isolated" traffictype="Guest" networkrate=500 specifyvlan=false ispersistent=true forvpc=true networkmode="NATTED" conservemode=true egressdefaultpolicy=true ispublic=true enable=true specifyipranges=false supportedservices="Vpn,Dhcp,Dns,Lb,UserData,SourceNat,StaticNat,PortForwarding,NetworkACL" serviceproviderlist[0].service="Vpn" serviceproviderlist[0].provider="VpcVirtualRouter" serviceproviderlist[1].service="Dhcp" serviceproviderlist[1].provider="VpcVirtualRouter" serviceproviderlist[2].service="Dns" serviceproviderlist[2].provider="VpcVirtualRouter" serviceproviderlist[3].service="Lb" serviceproviderlist[3].provider="InternalLbVm" serviceproviderlist[4].service="UserData" serviceproviderlist[4].provider="VpcVirtualRouter" serviceproviderlist[5].service="SourceNat" serviceproviderlist[5].provider="VpcVirtualRouter" serviceproviderlist[6].service="StaticNat" serviceproviderlist[6].provider="VpcVirtualRouter" serviceproviderlist[7].service="PortForwarding" serviceproviderlist[7].provider="VpcVirtualRouter" serviceproviderlist[8].service="NetworkACL" serviceproviderlist[8].provider="VpcVirtualRouter" details.internallbprovider="InternalLbVm"
```

### VPC Offerings

- **Format**: `acs.vpc.<network_mode>.<feature>`
- **Naming conventions**:
  - **network_mode**:
    - `natted` - VPC with NATTED networking
    - `routed` - VPC with ROUTED networking (not covered yet)

| Offering Name | Description | Internet Protocol | Provider | Network Mode | Routing Mode | Supported services (Service Provider) | Redundant VPC Router | Compute Offering | Public | Zone |
|---------------|-------------|-------------------|----------|--------------|--------------|---------------------------------------|----------------------|------------------|--------|------|
| `acs.vpc.natted.virtual-router` | VPC with NATTED networking and Single Virtual Router | IPv4 | VPC Virutal Router | NATTED | N/A | Vpn(VpcVirtualRouter), Dhcp(VpcVirtualRouter), Dns(VpcVirtualRouter), Lb(VpcVirtualRouter), Gateway(VpcVirtualRouter), UserData (VpcVirtualRouter), SourceNat(VpcVirtualRouter), StaticNat(VpcVirtualRouter), PortForwarding(VpcVirtualRouter), NetworkACL(VpcVirtualRouter) | false | System Offering for VPC Router | true | null |
| `acs.vpc.natted.redundant-virtual-router` | VPC with NATTED networking and Redundant Virtual Router | IPv4 | VPC Virutal Router | NATTED | N/A | Vpn(VpcVirtualRouter), Dhcp(VpcVirtualRouter), Dns(VpcVirtualRouter), Lb(VpcVirtualRouter), Gateway(VpcVirtualRouter), UserData (VpcVirtualRouter) , SourceNat(VpcVirtualRouter), StaticNat(VpcVirtualRouter), PortForwarding(VpcVirtualRouter), NetworkACL(VpcVirtualRouter) | true | System Offering for VPC Router | true | null |
| `acs.vpc.natted.redundant-virtual-router-internal-lb-vm` | VPC with NATTED networking and Redundant Virtual Router with Internal LB VM | IPv4 | VPC Virutal Router | NATTED | N/A | Vpn(VpcVirtualRouter), Dhcp(VpcVirtualRouter), Dns(VpcVirtualRouter), Lb(InternalLbVm), Gateway(VpcVirtualRouter), UserData (VpcVirtualRouter) , SourceNat(VpcVirtualRouter), StaticNat(VpcVirtualRouter), PortForwarding(VpcVirtualRouter), NetworkACL(VpcVirtualRouter) | true | System Offering for VPC Router | true | null |
| `acs.vpc.natted.virtual-router-cloud-drive` | VPC with NATTED networking and Single Virtual Router with Cloud-Drive for DHCP/DNS/Userdata | IPv4 | VPC Virutal Router | NATTED | N/A | Vpn(VpcVirtualRouter), Dhcp(ConfigDrive), Dns(ConfigDrive), Lb(VpcVirtualRouter), Gateway(VpcVirtualRouter), UserData (ConfigDrive) , SourceNat(VpcVirtualRouter), StaticNat(VpcVirtualRouter), PortForwarding(VpcVirtualRouter), NetworkACL(VpcVirtualRouter) | false | System Offering for VPC Router | true | null |
| `acs.vpc.natted.redundant-virtual-router-cloud-drive` | VPC with NATTED networking and Redundant Virtual Router with Cloud-Drive for DHCP/DNS/Userdata | IPv4 | VPC Virutal Router | NATTED | N/A | Vpn(VpcVirtualRouter), Dhcp(ConfigDrive), Dns(ConfigDrive), Lb(VpcVirtualRouter), Gateway(VpcVirtualRouter), UserData (ConfigDrive) , SourceNat(VpcVirtualRouter), StaticNat(VpcVirtualRouter), PortForwarding(VpcVirtualRouter), NetworkACL(VpcVirtualRouter) | true | System Offering for VPC Router | true | null |

#### Create VPC Offerings via CLI

```sh
cmk
create vpcoffering name="acs.vpc.natted.virtual-router" displaytext="VPC with NATTED networking and Single Virtual Router" internetprotocol="IPv4" networkmode="NATTED" ispublic=true enable=true supportedservices="Vpn,Dhcp,Dns,Lb,Gateway,UserData,SourceNat,StaticNat,PortForwarding,NetworkACL" serviceproviderlist.service="Vpn" serviceproviderlist.provider="VpcVirtualRouter" serviceproviderlist.service="Dhcp" serviceproviderlist.provider="VpcVirtualRouter" serviceproviderlist.service="Dns" serviceproviderlist.provider="VpcVirtualRouter" serviceproviderlist.service="Lb" serviceproviderlist.provider="VpcVirtualRouter" serviceproviderlist.service="Gateway" serviceproviderlist.provider="VpcVirtualRouter" serviceproviderlist.service="UserData" serviceproviderlist.provider="VpcVirtualRouter" serviceproviderlist.service="SourceNat" serviceproviderlist.provider="VpcVirtualRouter" serviceproviderlist.service="StaticNat" serviceproviderlist.provider="VpcVirtualRouter" serviceproviderlist.service="PortForwarding" serviceproviderlist.provider="VpcVirtualRouter" serviceproviderlist.service="NetworkACL" serviceproviderlist.provider="VpcVirtualRouter" serviceCapabilityList[0].service="SourceNat" serviceCapabilityList[0].capabilitytype="RedundantRouter" serviceCapabilityList[0].capabilityvalue="false"
create vpcoffering name="acs.vpc.natted.redundant-virtual-router" displaytext="VPC with NATTED networking and Redundant Virtual Router" internetprotocol="IPv4" networkmode="NATTED" ispublic=true enable=true supportedservices="Vpn,Dhcp,Dns,Lb,Gateway,UserData,SourceNat,StaticNat,PortForwarding,NetworkACL" serviceproviderlist.service="Vpn" serviceproviderlist.provider="VpcVirtualRouter" serviceproviderlist.service="Dhcp" serviceproviderlist.provider="VpcVirtualRouter" serviceproviderlist.service="Dns" serviceproviderlist.provider="VpcVirtualRouter" serviceproviderlist.service="Lb" serviceproviderlist.provider="VpcVirtualRouter" serviceproviderlist.service="Gateway" serviceproviderlist.provider="VpcVirtualRouter" serviceproviderlist.service="UserData" serviceproviderlist.provider="VpcVirtualRouter" serviceproviderlist.service="SourceNat" serviceproviderlist.provider="VpcVirtualRouter" serviceproviderlist.service="StaticNat" serviceproviderlist.provider="VpcVirtualRouter" serviceproviderlist.service="PortForwarding" serviceproviderlist.provider="VpcVirtualRouter" serviceproviderlist.service="NetworkACL" serviceproviderlist.provider="VpcVirtualRouter" serviceCapabilityList[0].service="SourceNat" serviceCapabilityList[0].capabilitytype="RedundantRouter" serviceCapabilityList[0].capabilityvalue="true"
create vpcoffering name="acs.vpc.natted.redundant-virtual-router-internal-lb-vm" displaytext="VPC with NATTED networking and Redundant Virtual Router with Internal LB VM" internetprotocol="IPv4" networkmode="NATTED" ispublic=true enable=true supportedservices="Vpn,Dhcp,Dns,Lb,Gateway,UserData,SourceNat,StaticNat,PortForwarding,NetworkACL" serviceproviderlist.service="Vpn" serviceproviderlist.provider="VpcVirtualRouter" serviceproviderlist.service="Dhcp" serviceproviderlist.provider="VpcVirtualRouter" serviceproviderlist.service="Dns" serviceproviderlist.provider="VpcVirtualRouter" serviceproviderlist.service="Lb" serviceproviderlist.provider="InternalLbVm" serviceproviderlist.service="Gateway" serviceproviderlist.provider="VpcVirtualRouter" serviceproviderlist.service="UserData" serviceproviderlist.provider="VpcVirtualRouter" serviceproviderlist.service="SourceNat" serviceproviderlist.provider="VpcVirtualRouter" serviceproviderlist.service="StaticNat" serviceproviderlist.provider="VpcVirtualRouter" serviceproviderlist.service="PortForwarding" serviceproviderlist.provider="VpcVirtualRouter" serviceproviderlist.service="NetworkACL" serviceproviderlist.provider="VpcVirtualRouter" serviceCapabilityList[0].service="SourceNat" serviceCapabilityList[0].capabilitytype="RedundantRouter" serviceCapabilityList[0].capabilityvalue="true"
create vpcoffering name="acs.vpc.natted.virtual-router-cloud-drive" displaytext="VPC with NATTED networking and Single Virtual Router with Cloud-Drive for DHCP/DNS/Userdata" internetprotocol="IPv4" networkmode="NATTED" ispublic=true enable=true supportedservices="Vpn,Dhcp,Dns,Lb,Gateway,UserData,SourceNat,StaticNat,PortForwarding,NetworkACL" serviceproviderlist.service="Vpn" serviceproviderlist.provider="VpcVirtualRouter" serviceproviderlist.service="Dhcp" serviceproviderlist.provider="ConfigDrive" serviceproviderlist.service="Dns" serviceproviderlist.provider="ConfigDrive" serviceproviderlist.service="Lb" serviceproviderlist.provider="VpcVirtualRouter" serviceproviderlist.service="Gateway" serviceproviderlist.provider="VpcVirtualRouter" serviceproviderlist.service="UserData" serviceproviderlist.provider="ConfigDrive" serviceproviderlist.service="SourceNat" serviceproviderlist.provider="VpcVirtualRouter" serviceproviderlist.service="StaticNat" serviceproviderlist.provider="VpcVirtualRouter" serviceproviderlist.service="PortForwarding" serviceproviderlist.provider="VpcVirtualRouter" serviceproviderlist.service="NetworkACL" serviceproviderlist.provider="VpcVirtualRouter" serviceCapabilityList[0].service="SourceNat" serviceCapabilityList[0].capabilitytype="RedundantRouter" serviceCapabilityList[0].capabilityvalue="false"
create vpcoffering name="acs.vpc.natted.redundant-virtual-router-cloud-drive" displaytext="VPC with NATTED networking and Redundant Virtual Router with Cloud-Drive for DHCP/DNS/Userdata" internetprotocol="IPv4" networkmode="NATTED" ispublic=true enable=true supportedservices="Vpn,Dhcp,Dns,Lb,Gateway,UserData,SourceNat,StaticNat,PortForwarding,NetworkACL" serviceproviderlist.service="Vpn" serviceproviderlist.provider="VpcVirtualRouter" serviceproviderlist.service="Dhcp" serviceproviderlist.provider="ConfigDrive" serviceproviderlist.service="Dns" serviceproviderlist.provider="ConfigDrive" serviceproviderlist.service="Lb" serviceproviderlist.provider="VpcVirtualRouter" serviceproviderlist.service="Gateway" serviceproviderlist.provider="VpcVirtualRouter" serviceproviderlist.service="UserData" serviceproviderlist.provider="ConfigDrive" serviceproviderlist.service="SourceNat" serviceproviderlist.provider="VpcVirtualRouter" serviceproviderlist.service="StaticNat" serviceproviderlist.provider="VpcVirtualRouter" serviceproviderlist.service="PortForwarding" serviceproviderlist.provider="VpcVirtualRouter" serviceproviderlist.service="NetworkACL" serviceproviderlist.provider="VpcVirtualRouter" serviceCapabilityList[0].service="SourceNat" serviceCapabilityList[0].capabilitytype="RedundantRouter" serviceCapabilityList[0].capabilityvalue="true"
```
