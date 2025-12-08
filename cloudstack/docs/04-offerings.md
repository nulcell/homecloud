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

| Offering Name         | Description              | vCPU | CPU Speed (MHz) | RAM (MB) | Network Bandwidth (Mbps) | GPU (vGPU) | Compute only disk offering | Storage type | Provisioning type | Write-cache type | QoS type | Root disk size (GB) | Encrypt |
| --------------------- | ------------------------ | ---- | --------------- | -------- | ------------------------ | ---------- | -------------------------- | ------------ | ----------------- | ---------------- | -------- | ------------------- | ------- |
| `acs.comp.gen.small`  | General Purpose Small    | 1    | 4000            | 1024     | 200                      | none       | true                       | Shared       | Thin              | No disk cache    | None     | 30                  | false   |
| `acs.comp.gen.medium` | General Purpose Medium   | 2    | 4000            | 2048     | 300                      | none       | true                       | Shared       | Thin              | No disk cache    | None     | 50                  | false   |
| `acs.comp.gen.large`  | General Purpose Large    | 4    | 4000            | 4096     | 500                      | none       | true                       | Shared       | Thin              | No disk cache    | None     | 100                 | false   |
| `acs.comp.gen.xlarge` | General Purpose xLarge   | 8    | 4000            | 8192     | 500                      | none       | true                       | Shared       | Thin              | No disk cache    | None     | 100                 | false   |
| `acs.comp.mem.small`  | Memory Optimized Small   | 1    | 4000            | 2048     | 200                      | none       | true                       | Shared       | Thin              | No disk cache    | None     | 30                  | false   |
| `acs.comp.mem.medium` | Memory Optimized Medium  | 2    | 4000            | 4096     | 300                      | none       | true                       | Shared       | Thin              | No disk cache    | None     | 50                  | false   |
| `acs.comp.mem.large`  | Memory Optimized Large   | 4    | 4000            | 8192     | 500                      | none       | true                       | Shared       | Thin              | No disk cache    | None     | 100                 | false   |
| `acs.comp.mem.xlarge` | Memory Optimized xLarge  | 8    | 4000            | 16384    | 500                      | none       | true                       | Shared       | Thin              | No disk cache    | None     | 100                 | false   |
| `acs.comp.ssd.small`  | Storage Optimized Small  | 1    | 4000            | 1024     | 200                      | none       | false                      | Local        | Thin              | No disk cache    | None     | 30                  | false   |
| `acs.comp.ssd.medium` | Storage Optimized Medium | 2    | 4000            | 2048     | 300                      | none       | false                      | Local        | Thin              | No disk cache    | None     | 50                  | false   |
| `acs.comp.ssd.large`  | Storage Optimized Large  | 4    | 4000            | 4096     | 500                      | none       | false                      | Local        | Thin              | No disk cache    | None     | 100                 | false   |
| `acs.comp.ssd.xlarge` | Storage Optimized xLarge | 8    | 4000            | 8192     | 500                      | none       | false                      | Local        | Thin              | No disk cache    | None     | 100                 | false   |

- **General options across all offerings**:
  - **Offer HA**: true
  - **Dynamic scaling enabled**: false
  - **CPU cap**: false (no limit on CPU Speed, so it is always the max)
  - **Volatile**: false
  - **Deployment planner**: UserDispersingPlanner
  - **Public**: true
  - **Zone**: null (all zones)
  - **Purge Resources**: true

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

| Offering Name            | Description                     | Storage type | Provisioning type | Encrypt | Disk size strictness | Custom disk size | Size (GB) | QoS type | Write-cache Type | Public | Zone |
| ------------------------ | ------------------------------- | ------------ | ----------------- | ------- | -------------------- | ---------------- | --------- | -------- | ---------------- | ------ | ---- |
| `acs.disk.shared.custom` | Shared Storage Custom Size Disk | Shared       | Thin              | false   | false                | true             | null      | None     | No Disk Cache    | true   | null |
| `acs.disk.local.custom`  | Local Storage Custom Size Disk  | Local        | Thin              | false   | false                | true             | null      | None     | No Disk Cache    | true   | null |
| `acs.disk.shared.small`  | Shared Storage Small Disk       | Shared       | Thin              | false   | false                | false            | 30        | None     | No Disk Cache    | true   | null |
| `acs.disk.shared.medium` | Shared Storage Medium Disk      | Shared       | Thin              | false   | false                | false            | 50        | None     | No Disk Cache    | true   | null |
| `acs.disk.shared.large`  | Shared Storage Large Disk       | Shared       | Thin              | false   | false                | false            | 100       | None     | No Disk Cache    | true   | null |
| `acs.disk.shared.xlarge` | Shared Storage XLarge Disk      | Shared       | Thin              | false   | false                | false            | 200       | None     | No Disk Cache    | true   | null |
| `acs.disk.local.small`   | Local Storage Small Disk        | Local        | Thin              | false   | false                | false            | 30        | None     | No Disk Cache    | true   | null |
| `acs.disk.local.medium`  | Local Storage Medium Disk       | Local        | Thin              | false   | false                | false            | 50        | None     | No Disk Cache    | true   | null |
| `acs.disk.local.large`   | Local Storage Large Disk        | Local        | Thin              | false   | false                | false            | 100       | None     | No Disk Cache    | true   | null |
| `acs.disk.local.xlarge`  | Local Storage xLarge Disk       | Local        | Thin              | false   | false                | false            | 200       | None     | No Disk Cache    | true   | null |

## Network Offerings

- **Format**: `acs.net.<type>.<feature>`
- **Naming conventions**:
  - **type**:
    - `isolated` - Isolated Network
    - `vpc` - Isolated VPC Network
    - `shared` - Shared Network
    - `l2` - L2 Network (not covered yet)

| Offering Name                        | Description                                                     | Network rate (Mb/s) | Guest Type | Internet protocol | Specify VLAN | Persistent | VPC   | Provider | Network Mode | Promiscuous mode | Forged transmits | MAC address changes | MAC learning | Supported services (Service Provider)                                                                                                                                                                                                              | Load balancer type | Compute Offering                                                   | Redundant router | Supported source NAT type | Supports auto scaling | Conserve mode | Default egress policy | Public | Zone |
| ------------------------------------ | --------------------------------------------------------------- | ------------------- | ---------- | ----------------- | ------------ | ---------- | ----- | -------- | ------------ | ---------------- | ---------------- | ------------------- | ------------ | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------ | ------------------------------------------------------------------ | ---------------- | ------------------------- | --------------------- | ------------- | --------------------- | ------ | ---- |
| `acs.net.shared.core-redundant`      | Shared Network with Redundant Virtual Router                    | 500                 | Shared     | N/A               | false        | N/A        | N/A   | NONE     | NATTED       | None             | None             | None                | None         | Vpn(VirtualRouter), Dhcp(VirtualRouter), Dns(VirtualRouter), Firewall(VirtualRouter), Lb(VirtualRouter), UserData (VirtualRouter) , SourceNat(VirtualRouter), StaticNat(VirtualRouter), PortForwarding(VirtualRouter)                              | N/A                | System Offering for Software Router                                | true             | Per Account NAT           | true                  | true          | allow                 | true   | null |
| `acs.net.shared.core-redundant-vlan` | Shared Network with Redundant Virtual Router and VLAN specified | 500                 | Shared     | N/A               | true         | N/A        | N/A   | NONE     | NATTED       | None             | None             | None                | None         | Vpn(VirtualRouter), Dhcp(VirtualRouter), Dns(VirtualRouter), Firewall(VirtualRouter), Lb(VirtualRouter), UserData (VirtualRouter) , SourceNat(VirtualRouter), StaticNat(VirtualRouter), PortForwarding(VirtualRouter)                              | N/A                | System Offering for Software Router                                | true             | Per Account NAT           | true                  | true          | allow                 | true   | null |
| `acs.net.isolated.core`              | Isolated Network with Virtual Router                            | 500                 | Isolated   | IPv4              | false        | true       | false | NONE     | NATTED       | None             | None             | None                | None         | Vpn(VirtualRouter), Dhcp(VirtualRouter), Dns(VirtualRouter), Firewall(VirtualRouter), Lb(VirtualRouter), UserData (VirtualRouter) , SourceNat(VirtualRouter), StaticNat(VirtualRouter), PortForwarding(VirtualRouter)                              | N/A                | System Offering for Software Router                                | false            | Per Account NAT           | true                  | true          | allow                 | true   | null |
| `acs.net.isolated.core-redundant`    | Isolated Network with Redundant Virtual Router                  | 500                 | Isolated   | IPv4              | false        | true       | false | NONE     | NATTED       | None             | None             | None                | None         | Vpn(VirtualRouter), Dhcp(VirtualRouter), Dns(VirtualRouter), Firewall(VirtualRouter), Lb(VirtualRouter), UserData (VirtualRouter) , SourceNat(VirtualRouter), StaticNat(VirtualRouter), PortForwarding(VirtualRouter)                              | N/A                | System Offering for Software Router                                | true             | Per Account NAT           | true                  | true          | allow                 | true   | null |
| `acs.net.vpc.core-internal-lb`       | VPC Network with VpcVirtualRouter and Internal LB VM            | 500                 | Isolated   | IPv4              | false        | true       | true  | NONE     | NATTED       | None             | None             | None                | None         | Vpn(VpcVirtualRouter), Dhcp(VpcVirtualRouter), Dns(VpcVirtualRouter), Lb(InternalLbVm), UserData (VpcVirtualRouter) , SourceNat(VpcVirtualRouter), StaticNat(VpcVirtualRouter), PortForwarding(VpcVirtualRouter), NetworkACL(VpcVirtualRouter)     | Internal LB        | System Offering for VPC Router (would just use VPC Virtual Router) | N/A              | Per Account NAT           | true                  | true          | allow                 | true   | null |
| `acs.net.vpc.core-public-lb`         | VPC Network with VpcVirtualRouter and Public LB                 | 500                 | Isolated   | IPv4              | false        | true       | true  | NONE     | NATTED       | None             | None             | None                | None         | Vpn(VpcVirtualRouter), Dhcp(VpcVirtualRouter), Dns(VpcVirtualRouter), Lb(VpcVirtualRouter), UserData (VpcVirtualRouter) , SourceNat(VpcVirtualRouter), StaticNat(VpcVirtualRouter), PortForwarding(VpcVirtualRouter), NetworkACL(VpcVirtualRouter) | Public LB          | System Offering for VPC Router (would just use VPC Virtual Router) | N/A              | Per Account NAT           | true                  | true          | allow                 | true   | null |

## VPC Offerings

- **Format**: `acs.vpc.<network_mode>.<feature>`
- **Naming conventions**:
  - **network_mode**:
    - `natted` - VPC with NATTED networking
    - `routed` - VPC with ROUTED networking (not covered yet)

| Offering Name                   | Description                                                                          | Internet Protocol | Provider           | Network Mode | Routing Mode | Supported services (Service Provider)                                                                                                                                                                                                                                                                                          | Redundant VPC Router | Compute Offering               | Public | Zone |
| ------------------------------- | ------------------------------------------------------------------------------------ | ----------------- | ------------------ | ------------ | ------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | -------------------- | ------------------------------ | ------ | ---- |
| `acs.vpc.natted.core`           | NATTED Single Virtual Router VPC with VpcVirtualRouter, ConfigDrive, InternalLbVm    | IPv4              | VPC Virutal Router | NATTED       | N/A          | Vpn(VpcVirtualRouter), Dhcp(VpcVirtualRouter,ConfigDrive), Dns(VpcVirtualRouter,ConfigDrive), Lb(InternalLbVm,VpcVirtualRouter), Gateway(VpcVirtualRouter), UserData (VpcVirtualRouter,ConfigDrive) , SourceNat(VpcVirtualRouter), StaticNat(VpcVirtualRouter), PortForwarding(VpcVirtualRouter), NetworkACL(VpcVirtualRouter) | false                | System Offering for VPC Router | true   | null |
| `acs.vpc.natted.redundant-core` | NATTED Redundant Virtual Router VPC with VpcVirtualRouter, ConfigDrive, InternalLbVm | IPv4              | VPC Virutal Router | NATTED       | N/A          | Vpn(VpcVirtualRouter), Dhcp(VpcVirtualRouter,ConfigDrive), Dns(VpcVirtualRouter,ConfigDrive), Lb(InternalLbVm,VpcVirtualRouter), Gateway(VpcVirtualRouter), UserData (VpcVirtualRouter,ConfigDrive) , SourceNat(VpcVirtualRouter), StaticNat(VpcVirtualRouter), PortForwarding(VpcVirtualRouter), NetworkACL(VpcVirtualRouter) | true                 | System Offering for VPC Router | true   | null |
