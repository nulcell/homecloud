# Service Offerings

Once all offerings have been created, disable the default offerings in CloudStack to avoid confusion.

## Compute Offerings

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

### Create Service Offerings via CLI

```sh
cmk
create serviceoffering name="acs.comp.gen.small" displaytext="General Purpose Small" cpunumber=1 cpuspeed=4000 memory=1024 networkrate=200 offerha=true dynamicscalingenabled=false limitcpuuse=false isvolatile=false deploymentplanner="UserDispersingPlanner" ispublic=true storagetype="shared" provisioningtype="thin" diskofferingstrictness=false rootdisksize=10 encryptroot=true purgeresources=true
create serviceoffering name="acs.comp.gen.medium" displaytext="General Purpose Medium" cpunumber=2 cpuspeed=4000 memory=2048 networkrate=300 offerha=true dynamicscalingenabled=false limitcpuuse=false isvolatile=false deploymentplanner="UserDispersingPlanner" ispublic=true storagetype="shared" provisioningtype="thin" diskofferingstrictness=false rootdisksize=10 encryptroot=true purgeresources=true
create serviceoffering name="acs.comp.gen.large" displaytext="General Purpose Large" cpunumber=4 cpuspeed=4000 memory=4096 networkrate=500 offerha=true dynamicscalingenabled=false limitcpuuse=false isvolatile=false deploymentplanner="UserDispersingPlanner" ispublic=true storagetype="shared" provisioningtype="thin" diskofferingstrictness=false rootdisksize=10 encryptroot=true purgeresources=true
create serviceoffering name="acs.comp.gen.xlarge" displaytext="General Purpose xLarge" cpunumber=8 cpuspeed=4000 memory=8192 networkrate=500 offerha=true dynamicscalingenabled=false limitcpuuse=false isvolatile=false deploymentplanner="UserDispersingPlanner" ispublic=true storagetype="shared" provisioningtype="thin" diskofferingstrictness=false rootdisksize=10 encryptroot=true purgeresources=true
create serviceoffering name="acs.comp.mem.small" displaytext="Memory Optimized Small" cpunumber=1 cpuspeed=4000 memory=2048 networkrate=200 offerha=true dynamicscalingenabled=false limitcpuuse=false isvolatile=false deploymentplanner="UserDispersingPlanner" ispublic=true storagetype="shared" provisioningtype="thin" diskofferingstrictness=false rootdisksize=10 encryptroot=true purgeresources=true
create serviceoffering name="acs.comp.mem.medium" displaytext="Memory Optimized Medium" cpunumber=2 cpuspeed=4000 memory=4096 networkrate=300 offerha=true dynamicscalingenabled=false limitcpuuse=false isvolatile=false deploymentplanner="UserDispersingPlanner" ispublic=true storagetype="shared" provisioningtype="thin" diskofferingstrictness=false rootdisksize=10 encryptroot=true purgeresources=true
create serviceoffering name="acs.comp.mem.large" displaytext="Memory Optimized Large" cpunumber=4 cpuspeed=4000 memory=8192 networkrate=500 offerha=true dynamicscalingenabled=false limitcpuuse=false isvolatile=false deploymentplanner="UserDispersingPlanner" ispublic=true storagetype="shared" provisioningtype="thin" diskofferingstrictness=false rootdisksize=10 encryptroot=true purgeresources=true
create serviceoffering name="acs.comp.mem.xlarge" displaytext="Memory Optimized xLarge" cpunumber=8 cpuspeed=4000 memory=16384 networkrate=500 offerha=true dynamicscalingenabled=false limitcpuuse=false isvolatile=false deploymentplanner="UserDispersingPlanner" ispublic=true storagetype="shared" provisioningtype="thin" diskofferingstrictness=false rootdisksize=10 encryptroot=true purgeresources=true
create serviceoffering name="acs.comp.ssd.small" displaytext="Storage Optimized Small" cpunumber=1 cpuspeed=4000 memory=1024 networkrate=200 offerha=false dynamicscalingenabled=false limitcpuuse=false isvolatile=false deploymentplanner="UserDispersingPlanner" ispublic=true storagetype="local" provisioningtype="thin" diskofferingstrictness=false rootdisksize=50 encryptroot=true purgeresources=true
create serviceoffering name="acs.comp.ssd.medium" displaytext="Storage Optimized Medium" cpunumber=2 cpuspeed=4000 memory=2048 networkrate=300 offerha=false dynamicscalingenabled=false limitcpuuse=false isvolatile=false deploymentplanner="UserDispersingPlanner" ispublic=true storagetype="local" provisioningtype="thin" diskofferingstrictness=false rootdisksize=100 encryptroot=true purgeresources=true
create serviceoffering name="acs.comp.ssd.large" displaytext="Storage Optimized Large" cpunumber=4 cpuspeed=4000 memory=4096 networkrate=500 offerha=false dynamicscalingenabled=false limitcpuuse=false isvolatile=false deploymentplanner="UserDispersingPlanner" ispublic=true storagetype="local" provisioningtype="thin" diskofferingstrictness=false rootdisksize=200 encryptroot=true purgeresources=true
create serviceoffering name="acs.comp.ssd.xlarge" displaytext="Storage Optimized xLarge" cpunumber=8 cpuspeed=4000 memory=8192 networkrate=500 offerha=false dynamicscalingenabled=false limitcpuuse=false isvolatile=false deploymentplanner="UserDispersingPlanner" ispublic=true storagetype="local" provisioningtype="thin" diskofferingstrictness=false rootdisksize=400 encryptroot=true purgeresources=true
```
  
## Disk Offerings

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

### Create Disk Offerings via CLI

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

## Network Offerings

- **Format**: `acs.net.<type>.<feature>`
- **Naming conventions**:
  - **type**:
    - `isolated` - Isolated Network
    - `vpc` - Isolated VPC Network
    - `shared` - Shared Network
    - `l2` - L2 Network (not covered yet)

| Offering Name | Description | Network rate (Mb/s) | Guest Type | Internet protocol | Specify VLAN | Persistent | VPC | Provider | Network Mode | Promiscuous mode | Forged transmits | MAC address changes | MAC learning | Supported services (Service Provider) | Load balancer type | Compute Offering | Redundant router | Supported source NAT type | Supports auto scaling | Conserve mode | Default egress policy | Public | Zone |
|---------------|-------------|---------------------|------------|-------------------|--------------|------------|-----|----------|--------------|------------------|------------------|--------------------|--------------|---------------------------------------|--------------------|------------------|------------------|--------------------------|-----------------------|---------------|-----------------------|--------|------|
| `acs.net.shared.core-redundant` | Shared Network with Redundant Virtual Router | 500 | Shared | N/A | false | N/A | N/A | NONE | NATTED | None | None | None | None | Vpn(VirtualRouter), Dhcp(VirtualRouter), Dns(VirtualRouter), Firewall(VirtualRouter), Lb(VirtualRouter), UserData (VirtualRouter) , SourceNat(VirtualRouter), StaticNat(VirtualRouter), PortForwarding(VirtualRouter) | N/A | System Offering for Software Router | true | Per Account NAT | true | true | allow | true | null |
| `acs.net.shared.core-redundant-vlan` | Shared Network with Redundant Virtual Router and VLAN specified | 500 | Shared | N/A | true | N/A | N/A | NONE | NATTED | None | None | None | None | Vpn(VirtualRouter), Dhcp(VirtualRouter), Dns(VirtualRouter), Firewall(VirtualRouter), Lb(VirtualRouter), UserData (VirtualRouter) , SourceNat(VirtualRouter), StaticNat(VirtualRouter), PortForwarding(VirtualRouter) | N/A | System Offering for Software Router | true | Per Account NAT | true | true | allow | true | null |
| `acs.net.isolated.core` | Isolated Network with Virtual Router | 500 | Isolated | IPv4 | false | true | false | NONE | NATTED | None | None | None | None | Vpn(VirtualRouter), Dhcp(VirtualRouter), Dns(VirtualRouter), Firewall(VirtualRouter), Lb(VirtualRouter), UserData (VirtualRouter) , SourceNat(VirtualRouter), StaticNat(VirtualRouter), PortForwarding(VirtualRouter) | N/A | System Offering for Software Router | false | Per Account NAT | true | true | allow | true | null |
| `acs.net.isolated.core-redundant` | Isolated Network with Redundant Virtual Router | 500 | Isolated | IPv4 | false | true | false | NONE | NATTED | None | None | None | None | Vpn(VirtualRouter), Dhcp(VirtualRouter), Dns(VirtualRouter), Firewall(VirtualRouter), Lb(VirtualRouter), UserData (VirtualRouter) , SourceNat(VirtualRouter), StaticNat(VirtualRouter), PortForwarding(VirtualRouter) | N/A | System Offering for Software Router | true | Per Account NAT | true | true | allow | true | null |
| `acs.net.vpc.core-internal-lb` | VPC Network with VpcVirtualRouter and Internal LB VM | 500 | Isolated | IPv4 | false | true | true | NONE | NATTED | None | None | None | None | Vpn(VpcVirtualRouter), Dhcp(VpcVirtualRouter), Dns(VpcVirtualRouter), Lb(InternalLbVm), UserData (VpcVirtualRouter) , SourceNat(VpcVirtualRouter), StaticNat(VpcVirtualRouter), PortForwarding(VpcVirtualRouter), NetworkACL(VpcVirtualRouter) | Internal LB | System Offering for VPC Router (would just use VPC Virtual Router) | N/A | Per Account NAT | true | true | allow | true | null |
| `acs.net.vpc.core-public-lb` | VPC Network with VpcVirtualRouter and Public LB | 500 | Isolated | IPv4 | false | true | true | NONE | NATTED | None | None | None | None | Vpn(VpcVirtualRouter), Dhcp(VpcVirtualRouter), Dns(VpcVirtualRouter), Lb(VpcVirtualRouter), UserData (VpcVirtualRouter) , SourceNat(VpcVirtualRouter), StaticNat(VpcVirtualRouter), PortForwarding(VpcVirtualRouter), NetworkACL(VpcVirtualRouter) | Public LB | System Offering for VPC Router (would just use VPC Virtual Router) | N/A | Per Account NAT | true | true | allow | true | null |

### Create Network Offerings via CLI

```sh
cmk
create networkoffering name="acs.net.shared.core-redundant" displaytext="Shared Network with Redundant Virtual Router" guestiptype="Shared" traffictype="Guest" networkrate=500 specifyvlan=false conservemode=true egressdefaultpolicy=true ispublic=true enable=true specifyipranges=true ispersistent=false forvpc=false supportedservices="Vpn,Dhcp,Dns,Firewall,Lb,UserData,SourceNat,StaticNat,PortForwarding" serviceproviderlist[0].service="Vpn" serviceproviderlist[0].provider="VirtualRouter" serviceproviderlist[1].service="Dhcp" serviceproviderlist[1].provider="VirtualRouter" serviceproviderlist[2].service="Dns" serviceproviderlist[2].provider="VirtualRouter" serviceproviderlist[3].service="Firewall" serviceproviderlist[3].provider="VirtualRouter" serviceproviderlist[4].service="Lb" serviceproviderlist[4].provider="VirtualRouter" serviceproviderlist[5].service="UserData" serviceproviderlist[5].provider="VirtualRouter" serviceproviderlist[6].service="SourceNat" serviceproviderlist[6].provider="VirtualRouter" serviceproviderlist[7].service="StaticNat" serviceproviderlist[7].provider="VirtualRouter" serviceproviderlist[8].service="PortForwarding" serviceproviderlist[8].provider="VirtualRouter" serviceCapabilityList[0].service="SourceNat" serviceCapabilityList[0].capabilitytype="RedundantRouter" serviceCapabilityList[0].capabilityvalue="true"
create networkoffering name="acs.net.shared.core-redundant-vlan" displaytext="Shared Network with Redundant Virtual Router and VLAN specified" guestiptype="Shared" traffictype="Guest" networkrate=500 specifyvlan=true conservemode=true egressdefaultpolicy=true ispublic=true enable=true specifyipranges=true ispersistent=false forvpc=false supportedservices="Vpn,Dhcp,Dns,Firewall,Lb,UserData,SourceNat,StaticNat,PortForwarding" serviceproviderlist[0].service="Vpn" serviceproviderlist[0].provider="VirtualRouter" serviceproviderlist[1].service="Dhcp" serviceproviderlist[1].provider="VirtualRouter" serviceproviderlist[2].service="Dns" serviceproviderlist[2].provider="VirtualRouter" serviceproviderlist[3].service="Firewall" serviceproviderlist[3].provider="VirtualRouter" serviceproviderlist[4].service="Lb" serviceproviderlist[4].provider="VirtualRouter" serviceproviderlist[5].service="UserData" serviceproviderlist[5].provider="VirtualRouter" serviceproviderlist[6].service="SourceNat" serviceproviderlist[6].provider="VirtualRouter" serviceproviderlist[7].service="StaticNat" serviceproviderlist[7].provider="VirtualRouter" serviceproviderlist[8].service="PortForwarding" serviceproviderlist[8].provider="VirtualRouter" serviceCapabilityList[0].service="SourceNat" serviceCapabilityList[0].capabilitytype="RedundantRouter" serviceCapabilityList[0].capabilityvalue="true"


# Isolated Network offerings
create networkoffering name="acs.net.isolated.core" displaytext="Isolated Network with Redundant Virtual Router" guestiptype="Isolated" traffictype="Guest" networkrate=500 specifyvlan=false ispersistent=true forvpc=false networkmode="NATTED" conservemode=true egressdefaultpolicy=true ispublic=true enable=true specifyipranges=false supportedservices="Vpn,Dhcp,Dns,Firewall,Lb,UserData,SourceNat,StaticNat,PortForwarding" serviceproviderlist[0].service="Vpn" serviceproviderlist[0].provider="VirtualRouter" serviceproviderlist[1].service="Dhcp" serviceproviderlist[1].provider="VirtualRouter" serviceproviderlist[2].service="Dns" serviceproviderlist[2].provider="VirtualRouter" serviceproviderlist[3].service="Firewall" serviceproviderlist[3].provider="VirtualRouter" serviceproviderlist[4].service="Lb" serviceproviderlist[4].provider="VirtualRouter" serviceproviderlist[5].service="UserData" serviceproviderlist[5].provider="VirtualRouter" serviceproviderlist[6].service="SourceNat" serviceproviderlist[6].provider="VirtualRouter" serviceproviderlist[7].service="StaticNat" serviceproviderlist[7].provider="VirtualRouter" serviceproviderlist[8].service="PortForwarding" serviceproviderlist[8].provider="VirtualRouter"
create networkoffering name="acs.net.isolated.core-redundant" displaytext="Isolated Network with Redundant Virtual Router" guestiptype="Isolated" traffictype="Guest" networkrate=500 specifyvlan=false ispersistent=true forvpc=false networkmode="NATTED" conservemode=true egressdefaultpolicy=true ispublic=true enable=true specifyipranges=false supportedservices="Vpn,Dhcp,Dns,Firewall,Lb,UserData,SourceNat,StaticNat,PortForwarding" serviceproviderlist[0].service="Vpn" serviceproviderlist[0].provider="VirtualRouter" serviceproviderlist[1].service="Dhcp" serviceproviderlist[1].provider="VirtualRouter" serviceproviderlist[2].service="Dns" serviceproviderlist[2].provider="VirtualRouter" serviceproviderlist[3].service="Firewall" serviceproviderlist[3].provider="VirtualRouter" serviceproviderlist[4].service="Lb" serviceproviderlist[4].provider="VirtualRouter" serviceproviderlist[5].service="UserData" serviceproviderlist[5].provider="VirtualRouter" serviceproviderlist[6].service="SourceNat" serviceproviderlist[6].provider="VirtualRouter" serviceproviderlist[7].service="StaticNat" serviceproviderlist[7].provider="VirtualRouter" serviceproviderlist[8].service="PortForwarding" serviceproviderlist[8].provider="VirtualRouter" serviceCapabilityList[0].service="SourceNat" serviceCapabilityList[0].capabilitytype="RedundantRouter" serviceCapabilityList[0].capabilityvalue="true"


# VPC Network offerings
create networkoffering name="acs.net.vpc.core-internal-lb" displaytext="VPC Network with VpcVirtualRouter and Internal LB VM" guestiptype="Isolated" traffictype="Guest" networkrate=500 specifyvlan=false ispersistent=true forvpc=true networkmode="NATTED" conservemode=true egressdefaultpolicy=true ispublic=true enable=true specifyipranges=false internetprotocol="IPv4" guestiptype="Isolated" lbtype="internalLb" supportedservices="Vpn,Dhcp,Dns,Lb,UserData,SourceNat,StaticNat,PortForwarding,NetworkACL" serviceproviderlist[0].service="Vpn" serviceproviderlist[0].provider="VpcVirtualRouter" serviceproviderlist[1].service="Dhcp" serviceproviderlist[1].provider="VpcVirtualRouter" serviceproviderlist[2].service="Dns" serviceproviderlist[2].provider="VpcVirtualRouter" serviceproviderlist[3].service="Lb" serviceproviderlist[3].provider="InternalLbVm" serviceproviderlist[4].service="UserData" serviceproviderlist[4].provider="VpcVirtualRouter" serviceproviderlist[5].service="SourceNat" serviceproviderlist[5].provider="VpcVirtualRouter" serviceproviderlist[6].service="StaticNat" serviceproviderlist[6].provider="VpcVirtualRouter" serviceproviderlist[7].service="PortForwarding" serviceproviderlist[7].provider="VpcVirtualRouter" serviceproviderlist[8].service="NetworkACL" serviceproviderlist[8].provider="VpcVirtualRouter" serviceCapabilityList[0].service="SourceNat" serviceCapabilityList[0].capabilitytype="SupportedSourceNatTypes" serviceCapabilityList[0].capabilityvalue="peraccount" serviceCapabilityList[1].service="lb" serviceCapabilityList[1].capabilitytype="SupportedLbIsolation" serviceCapabilityList[1].capabilityvalue="dedicated" serviceCapabilityList[2].service="lb" serviceCapabilityList[2].capabilitytype="lbSchemes" serviceCapabilityList[2].capabilityvalue="internal"
create networkoffering name="acs.net.vpc.core-public-lb" displaytext="VPC Network with VpcVirtualRouter and Public LB" guestiptype="Isolated" traffictype="Guest" networkrate=500 specifyvlan=false ispersistent=true forvpc=true networkmode="NATTED" conservemode=true egressdefaultpolicy=true ispublic=true enable=true specifyipranges=false internetprotocol="IPv4" guestiptype="Isolated" lbtype="publicLb" vmautoscalingcapability="true" supportedservices="Vpn,Dhcp,Dns,Lb,UserData,SourceNat,StaticNat,PortForwarding,NetworkACL" serviceproviderlist[0].service="Vpn" serviceproviderlist[0].provider="VpcVirtualRouter" serviceproviderlist[1].service="Dhcp" serviceproviderlist[1].provider="VpcVirtualRouter" serviceproviderlist[2].service="Dns" serviceproviderlist[2].provider="VpcVirtualRouter" serviceproviderlist[3].service="Lb" serviceproviderlist[3].provider="VpcVirtualRouter" serviceproviderlist[4].service="UserData" serviceproviderlist[4].provider="VpcVirtualRouter" serviceproviderlist[5].service="SourceNat" serviceproviderlist[5].provider="VpcVirtualRouter" serviceproviderlist[6].service="StaticNat" serviceproviderlist[6].provider="VpcVirtualRouter" serviceproviderlist[7].service="PortForwarding" serviceproviderlist[7].provider="VpcVirtualRouter" serviceproviderlist[8].service="NetworkACL" serviceproviderlist[8].provider="VpcVirtualRouter" serviceCapabilityList[0].service="SourceNat" serviceCapabilityList[0].capabilitytype="SupportedSourceNatTypes" serviceCapabilityList[0].capabilityvalue="peraccount" serviceCapabilityList[1].service="lb" serviceCapabilityList[1].capabilitytype="VmAutoScaling" serviceCapabilityList[1].capabilityvalue="true" serviceCapabilityList[2].service="lb" serviceCapabilityList[2].capabilitytype="SupportedLbIsolation" serviceCapabilityList[2].capabilityvalue="dedicated"
```

## VPC Offerings

- **Format**: `acs.vpc.<network_mode>.<feature>`
- **Naming conventions**:
  - **network_mode**:
    - `natted` - VPC with NATTED networking
    - `routed` - VPC with ROUTED networking (not covered yet)

| Offering Name | Description | Internet Protocol | Provider | Network Mode | Routing Mode | Supported services (Service Provider) | Redundant VPC Router | Compute Offering | Public | Zone |
|---------------|-------------|-------------------|----------|--------------|--------------|---------------------------------------|----------------------|------------------|--------|------|
| `acs.vpc.natted.core` | NATTED Single Virtual Router VPC with VpcVirtualRouter, ConfigDrive, InternalLbVm | IPv4 | VPC Virutal Router | NATTED | N/A | Vpn(VpcVirtualRouter), Dhcp(VpcVirtualRouter,ConfigDrive), Dns(VpcVirtualRouter,ConfigDrive), Lb(InternalLbVm,VpcVirtualRouter), Gateway(VpcVirtualRouter), UserData (VpcVirtualRouter,ConfigDrive) , SourceNat(VpcVirtualRouter), StaticNat(VpcVirtualRouter), PortForwarding(VpcVirtualRouter), NetworkACL(VpcVirtualRouter) | false | System Offering for VPC Router | true | null |
| `acs.vpc.natted.redundant-core` | NATTED Redundant Virtual Router VPC with VpcVirtualRouter, ConfigDrive, InternalLbVm | IPv4 | VPC Virutal Router | NATTED | N/A | Vpn(VpcVirtualRouter), Dhcp(VpcVirtualRouter,ConfigDrive), Dns(VpcVirtualRouter,ConfigDrive), Lb(InternalLbVm,VpcVirtualRouter), Gateway(VpcVirtualRouter), UserData (VpcVirtualRouter,ConfigDrive) , SourceNat(VpcVirtualRouter), StaticNat(VpcVirtualRouter), PortForwarding(VpcVirtualRouter), NetworkACL(VpcVirtualRouter) | true | System Offering for VPC Router | true | null |

### Create VPC Offerings via CLI

```sh
cmk
create vpcoffering name="acs.vpc.natted.core" displaytext="NATTED Single Virtual Router VPC with VpcVirtualRouter, ConfigDrive, InternalLbVm" internetprotocol="IPv4" ispublic=true enable=true networkmode="NATTED" supportedservices="Vpn,Dhcp,Dns,Lb,Gateway,UserData,SourceNat,StaticNat,PortForwarding,NetworkACL" serviceproviderlist[0].service="Vpn" serviceproviderlist[0].provider="VpcVirtualRouter" serviceproviderlist[1].service="Dhcp" serviceproviderlist[1].provider="VpcVirtualRouter" serviceproviderlist[2].service="Dhcp" serviceproviderlist[2].provider="ConfigDrive" serviceproviderlist[3].service="Dns" serviceproviderlist[3].provider="VpcVirtualRouter" serviceproviderlist[4].service="Dns" serviceproviderlist[4].provider="ConfigDrive" serviceproviderlist[5].service="Lb" serviceproviderlist[5].provider="InternalLbVm" serviceproviderlist[6].service="Lb" serviceproviderlist[6].provider="VpcVirtualRouter" serviceproviderlist[7].service="Gateway" serviceproviderlist[7].provider="VpcVirtualRouter" serviceproviderlist[8].service="UserData" serviceproviderlist[8].provider="VpcVirtualRouter" serviceproviderlist[9].service="UserData" serviceproviderlist[9].provider="ConfigDrive" serviceproviderlist[10].service="SourceNat" serviceproviderlist[10].provider="VpcVirtualRouter" serviceproviderlist[11].service="StaticNat" serviceproviderlist[11].provider="VpcVirtualRouter" serviceproviderlist[12].service="PortForwarding" serviceproviderlist[12].provider="VpcVirtualRouter" serviceproviderlist[13].service="NetworkACL" serviceproviderlist[13].provider="VpcVirtualRouter"
create vpcoffering name="acs.vpc.natted.redundant-core" displaytext="NATTED Redundant Virtual Router VPC with VpcVirtualRouter, ConfigDrive, InternalLbVm" internetprotocol="IPv4" ispublic=true enable=true networkmode="NATTED" supportedservices="Vpn,Dhcp,Dns,Lb,Gateway,UserData,SourceNat,StaticNat,PortForwarding,NetworkACL" serviceproviderlist[0].service="Vpn" serviceproviderlist[0].provider="VpcVirtualRouter" serviceproviderlist[1].service="Dhcp" serviceproviderlist[1].provider="VpcVirtualRouter" serviceproviderlist[2].service="Dhcp" serviceproviderlist[2].provider="ConfigDrive" serviceproviderlist[3].service="Dns" serviceproviderlist[3].provider="VpcVirtualRouter" serviceproviderlist[4].service="Dns" serviceproviderlist[4].provider="ConfigDrive" serviceproviderlist[5].service="Lb" serviceproviderlist[5].provider="InternalLbVm" serviceproviderlist[6].service="Lb" serviceproviderlist[6].provider="VpcVirtualRouter" serviceproviderlist[7].service="Gateway" serviceproviderlist[7].provider="VpcVirtualRouter" serviceproviderlist[8].service="UserData" serviceproviderlist[8].provider="VpcVirtualRouter" serviceproviderlist[9].service="UserData" serviceproviderlist[9].provider="ConfigDrive" serviceproviderlist[10].service="SourceNat" serviceproviderlist[10].provider="VpcVirtualRouter" serviceproviderlist[11].service="StaticNat" serviceproviderlist[11].provider="VpcVirtualRouter" serviceproviderlist[12].service="PortForwarding" serviceproviderlist[12].provider="VpcVirtualRouter" serviceproviderlist[13].service="NetworkACL" serviceproviderlist[13].provider="VpcVirtualRouter" serviceCapabilityList[0].service="SourceNat" serviceCapabilityList[0].capabilitytype="RedundantRouter" serviceCapabilityList[0].capabilityvalue="true"
```
