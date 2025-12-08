# CloudMonkey CLI Setup

## CLI Configuration

### Admin User

```bash
cmk set profile admin
cmk set url http://10.10.17.10:8080/client/api
cmk set username $(op read "op://homecloud/CloudStack - admin/username")
cmk set password $(op read "op://homecloud/CloudStack - admin/password")
cmk set domain /
cmk set timeout 3600
cmk set asyncblock true
cmk set output json
cmk -p admin sync
```

### HomeCloud Admin User

Note: Ensure the `homecloud-admin` user and `/homecloud` domain are created via the CloudStack UI before running these commands.

```bash
cmk set profile homecloud-admin
cmk set url http://10.10.17.10:8080/client/api
cmk set username $(op read "op://homecloud/CloudStack - homecloud-admin/username")
cmk set password $(op read "op://homecloud/CloudStack - homecloud-admin/password")
cmk set domain /homecloud
cmk set timeout 3600
cmk set asyncblock true
cmk set output json
cmk -p homecloud-admin sync
```

## Account Setup

```bash
# Domain and Account
DOMAIN_NAME="homecloud"
DOMAIN_NETWORK="homecloud.internal"
ACCOUNT_NAME="homecloud"
ADMIN_USERNAME="$(op read "op://homecloud/CloudStack - homecloud-admin/username")"
ADMIN_PASSWORD="$(op read "op://homecloud/CloudStack - homecloud-admin/password")"
ADMIN_EMAIL="$(op read "op://homecloud/CloudStack - homecloud-admin/details/Email")"
ADMIN_FIRSTNAME="$(op read "op://homecloud/CloudStack - homecloud-admin/details/First name")"
ADMIN_LASTNAME="$(op read "op://homecloud/CloudStack - homecloud-admin/details/Last name")"
TIMEZONE="Europe/Amsterdam"

echo "Creating domain..."
DOMAIN_ID=$(cmk -p admin create domain \
  name="$DOMAIN_NAME" \
  networkdomain="$DOMAIN_NETWORK" \
  | jq -r '.domain.id')
echo "Domain created with ID: $DOMAIN_ID"

echo "Creating account..."
ACCOUNT_ID=$(cmk -p admin create account \
  accounttype=2 \
  domainid="$DOMAIN_ID" \
  email="$ADMIN_EMAIL" \
  firstname="$ADMIN_FIRSTNAME" \
  lastname="$ADMIN_LASTNAME" \
  password="$ADMIN_PASSWORD" \
  username="$ADMIN_USERNAME" \
  account="$ACCOUNT_NAME" \
  timezone="$TIMEZONE" \
  | jq -r '.account.id')
echo "Account created: $ACCOUNT_NAME (ID: $ACCOUNT_ID)"
```

## Global Settings

```bash
# Variables
ENDPOINT_URL="http://10.10.17.10:8080/client/api"  # Replace with your management server URL

# Access Settings
cmk -p admin update configuration name=metadata.allow.expose.domain value=true

# Compute - VM Settings
cmk -p admin update configuration name=cluster.cpu.allocated.capacity.disablethreshold value=1
cmk -p admin update configuration name=cluster.cpu.allocated.capacity.notificationthreshold value=1
cmk -p admin update configuration name=enable.additional.vm.configuration value=true
cmk -p admin update configuration name=enable.dynamic.scale.vm value=true
cmk -p admin update configuration name=instance.lease.enabled value=true
cmk -p admin update configuration name=system.vm.default.hypervisor value=KVM
cmk -p admin update configuration name=vm.allocation.algorithm value=userdispersing
cmk -p admin update configuration name=vm.deployment.planner value=UserDispersingPlanner
cmk -p admin update configuration name=vm.destroy.forcestop value=true
cmk -p admin update configuration name=vm.display.ovf.properties value=true
cmk -p admin update configuration name=vm.password.length value=12
cmk -p admin update configuration name=vm.userdata.max.length value=1048576
# Compute - Kubernetes Settings
cmk -p admin update configuration name=cloud.kubernetes.cluster.experimental.features.enabled value=true

# Storage Settings
cmk -p admin update configuration name=destroy.root.volume.on.vm.destruction value=true
cmk -p admin update configuration name=snapshot.delta.max value=32

# Network Settings
cmk -p admin update configuration name=network.throttling.rate value=500
cmk -p admin update configuration name=vpc.max.networks value=4
cmk -p admin update configuration name=vpc.tier.name.prepend value=true
cmk -p admin update configuration name=vpc.tier.name.prepend.delimiter value=_

cmk -p admin update configuration name=cloud.dns.name value=homecloud.internal
cmk -p admin update configuration name=guest.domain.suffix value=homecloud.internal

# Hypervisor - KVM Settings
cmk -p admin update configuration name=enable.kvm.host.auto.enable.disable value=true
cmk -p admin update configuration name=kvm.incremental.snapshot value=true
# Management Server - API Settings
cmk -p admin update configuration name=enable.ec2.api value=true
cmk -p admin update configuration name=enable.s3.api value=true

# System VMs - Console Proxy
cmk -p admin update configuration name=consoleproxy.sslEnabled value=true

# Miscellaneous
cmk -p admin update configuration name=endpoint.url value="$ENDPOINT_URL"
cmk -p admin update configuration name=store.download.follow.redirects value=true
echo "Global configuration completed."
```

## Zone Setup

TBD

## Service Offerings

### Compute Offering

```bash
cmk -p admin create serviceoffering name="acs.comp.gen.small"  displaytext="General Purpose Small"    cpunumber=1 cpuspeed=4000 memory=1024  networkrate=200 offerha=true  dynamicscalingenabled=false limitcpuuse=false isvolatile=false deploymentplanner="UserDispersingPlanner" ispublic=true storagetype="shared" provisioningtype="thin" diskofferingstrictness=false rootdisksize=30  encryptroot=false purgeresources=true
cmk -p admin create serviceoffering name="acs.comp.gen.medium" displaytext="General Purpose Medium"   cpunumber=2 cpuspeed=4000 memory=2048  networkrate=300 offerha=true  dynamicscalingenabled=false limitcpuuse=false isvolatile=false deploymentplanner="UserDispersingPlanner" ispublic=true storagetype="shared" provisioningtype="thin" diskofferingstrictness=false rootdisksize=50  encryptroot=false purgeresources=true
cmk -p admin create serviceoffering name="acs.comp.gen.large"  displaytext="General Purpose Large"    cpunumber=4 cpuspeed=4000 memory=4096  networkrate=500 offerha=true  dynamicscalingenabled=false limitcpuuse=false isvolatile=false deploymentplanner="UserDispersingPlanner" ispublic=true storagetype="shared" provisioningtype="thin" diskofferingstrictness=false rootdisksize=100 encryptroot=false purgeresources=true
cmk -p admin create serviceoffering name="acs.comp.gen.xlarge" displaytext="General Purpose xLarge"   cpunumber=8 cpuspeed=4000 memory=8192  networkrate=500 offerha=true  dynamicscalingenabled=false limitcpuuse=false isvolatile=false deploymentplanner="UserDispersingPlanner" ispublic=true storagetype="shared" provisioningtype="thin" diskofferingstrictness=false rootdisksize=100 encryptroot=false purgeresources=true
cmk -p admin create serviceoffering name="acs.comp.mem.small"  displaytext="Memory Optimized Small"   cpunumber=1 cpuspeed=4000 memory=2048  networkrate=200 offerha=true  dynamicscalingenabled=false limitcpuuse=false isvolatile=false deploymentplanner="UserDispersingPlanner" ispublic=true storagetype="shared" provisioningtype="thin" diskofferingstrictness=false rootdisksize=30  encryptroot=false purgeresources=true
cmk -p admin create serviceoffering name="acs.comp.mem.medium" displaytext="Memory Optimized Medium"  cpunumber=2 cpuspeed=4000 memory=4096  networkrate=300 offerha=true  dynamicscalingenabled=false limitcpuuse=false isvolatile=false deploymentplanner="UserDispersingPlanner" ispublic=true storagetype="shared" provisioningtype="thin" diskofferingstrictness=false rootdisksize=50  encryptroot=false purgeresources=true
cmk -p admin create serviceoffering name="acs.comp.mem.large"  displaytext="Memory Optimized Large"   cpunumber=4 cpuspeed=4000 memory=8192  networkrate=500 offerha=true  dynamicscalingenabled=false limitcpuuse=false isvolatile=false deploymentplanner="UserDispersingPlanner" ispublic=true storagetype="shared" provisioningtype="thin" diskofferingstrictness=false rootdisksize=100 encryptroot=false purgeresources=true
cmk -p admin create serviceoffering name="acs.comp.mem.xlarge" displaytext="Memory Optimized xLarge"  cpunumber=8 cpuspeed=4000 memory=16384 networkrate=500 offerha=true  dynamicscalingenabled=false limitcpuuse=false isvolatile=false deploymentplanner="UserDispersingPlanner" ispublic=true storagetype="shared" provisioningtype="thin" diskofferingstrictness=false rootdisksize=100 encryptroot=false purgeresources=true
cmk -p admin create serviceoffering name="acs.comp.ssd.small"  displaytext="Storage Optimized Small"  cpunumber=1 cpuspeed=4000 memory=1024  networkrate=200 offerha=false dynamicscalingenabled=false limitcpuuse=false isvolatile=false deploymentplanner="UserDispersingPlanner" ispublic=true storagetype="local"  provisioningtype="thin" diskofferingstrictness=false rootdisksize=30  encryptroot=false purgeresources=true
cmk -p admin create serviceoffering name="acs.comp.ssd.medium" displaytext="Storage Optimized Medium" cpunumber=2 cpuspeed=4000 memory=2048  networkrate=300 offerha=false dynamicscalingenabled=false limitcpuuse=false isvolatile=false deploymentplanner="UserDispersingPlanner" ispublic=true storagetype="local"  provisioningtype="thin" diskofferingstrictness=false rootdisksize=50  encryptroot=false purgeresources=true
cmk -p admin create serviceoffering name="acs.comp.ssd.large"  displaytext="Storage Optimized Large"  cpunumber=4 cpuspeed=4000 memory=4096  networkrate=500 offerha=false dynamicscalingenabled=false limitcpuuse=false isvolatile=false deploymentplanner="UserDispersingPlanner" ispublic=true storagetype="local"  provisioningtype="thin" diskofferingstrictness=false rootdisksize=100 encryptroot=false purgeresources=true
cmk -p admin create serviceoffering name="acs.comp.ssd.xlarge" displaytext="Storage Optimized xLarge" cpunumber=8 cpuspeed=4000 memory=8192  networkrate=500 offerha=false dynamicscalingenabled=false limitcpuuse=false isvolatile=false deploymentplanner="UserDispersingPlanner" ispublic=true storagetype="local"  provisioningtype="thin" diskofferingstrictness=false rootdisksize=100 encryptroot=false purgeresources=true
```

### Disk Offering

```bash
cmk -p admin create diskoffering name="acs.disk.shared.custom" displaytext="Shared Storage Custom Size Disk" storagetype="shared" customdisksize=true disksizeStrictness=false encrypt=false ispublic=true qostype="None" cachemode="none" customized=true
cmk -p admin create diskoffering name="acs.disk.local.custom"  displaytext="Local Storage Custom Size Disk"  storagetype="local"  customdisksize=true disksizeStrictness=false encrypt=false ispublic=true qostype="None" cachemode="none" customized=true

cmk -p admin create diskoffering name="acs.disk.shared.small"  displaytext="Shared Storage Small Disk"  storagetype="shared" disksize=30  customdisksize=false disksizeStrictness=false encrypt=false ispublic=true qostype="None" cachemode="none"
cmk -p admin create diskoffering name="acs.disk.shared.medium" displaytext="Shared Storage Medium Disk" storagetype="shared" disksize=50  customdisksize=false disksizeStrictness=false encrypt=false ispublic=true qostype="None" cachemode="none"
cmk -p admin create diskoffering name="acs.disk.shared.large"  displaytext="Shared Storage Large Disk"  storagetype="shared" disksize=100 customdisksize=false disksizeStrictness=false encrypt=false ispublic=true qostype="None" cachemode="none"
cmk -p admin create diskoffering name="acs.disk.shared.xlarge" displaytext="Shared Storage XLarge Disk" storagetype="shared" disksize=200 customdisksize=false disksizeStrictness=false encrypt=false ispublic=true qostype="None" cachemode="none"

cmk -p admin create diskoffering name="acs.disk.local.small"   displaytext="Local Storage Small Disk"  storagetype="local" disksize=30  customdisksize=false disksizeStrictness=false encrypt=false ispublic=true qostype="None" cachemode="none"
cmk -p admin create diskoffering name="acs.disk.local.medium"  displaytext="Local Storage Medium Disk" storagetype="local" disksize=50  customdisksize=false disksizeStrictness=false encrypt=false ispublic=true qostype="None" cachemode="none"
cmk -p admin create diskoffering name="acs.disk.local.large"   displaytext="Local Storage Large Disk"  storagetype="local" disksize=100 customdisksize=false disksizeStrictness=false encrypt=false ispublic=true qostype="None" cachemode="none"
cmk -p admin create diskoffering name="acs.disk.local.xlarge"  displaytext="Local Storage xLarge Disk" storagetype="local" disksize=200 customdisksize=false disksizeStrictness=false encrypt=false ispublic=true qostype="None" cachemode="none"
```

### Network Offering

```bash
cmk -p admin create networkoffering name="acs.net.shared.core-redundant"      displaytext="Shared Network with Redundant Virtual Router"                    guestiptype="Shared" traffictype="Guest" networkrate=500 specifyvlan=false conservemode=true egressdefaultpolicy=true ispublic=true enable=true specifyipranges=true ispersistent=false forvpc=false supportedservices="Vpn,Dhcp,Dns,Firewall,Lb,UserData,SourceNat,StaticNat,PortForwarding" serviceproviderlist[0].service="Vpn" serviceproviderlist[0].provider="VirtualRouter" serviceproviderlist[1].service="Dhcp" serviceproviderlist[1].provider="VirtualRouter" serviceproviderlist[2].service="Dns" serviceproviderlist[2].provider="VirtualRouter" serviceproviderlist[3].service="Firewall" serviceproviderlist[3].provider="VirtualRouter" serviceproviderlist[4].service="Lb" serviceproviderlist[4].provider="VirtualRouter" serviceproviderlist[5].service="UserData" serviceproviderlist[5].provider="VirtualRouter" serviceproviderlist[6].service="SourceNat" serviceproviderlist[6].provider="VirtualRouter" serviceproviderlist[7].service="StaticNat" serviceproviderlist[7].provider="VirtualRouter" serviceproviderlist[8].service="PortForwarding" serviceproviderlist[8].provider="VirtualRouter" serviceCapabilityList[0].service="SourceNat" serviceCapabilityList[0].capabilitytype="RedundantRouter" serviceCapabilityList[0].capabilityvalue="true"
cmk -p admin create networkoffering name="acs.net.shared.core-redundant-vlan" displaytext="Shared Network with Redundant Virtual Router and VLAN specified" guestiptype="Shared" traffictype="Guest" networkrate=500 specifyvlan=true  conservemode=true egressdefaultpolicy=true ispublic=true enable=true specifyipranges=true ispersistent=false forvpc=false supportedservices="Vpn,Dhcp,Dns,Firewall,Lb,UserData,SourceNat,StaticNat,PortForwarding" serviceproviderlist[0].service="Vpn" serviceproviderlist[0].provider="VirtualRouter" serviceproviderlist[1].service="Dhcp" serviceproviderlist[1].provider="VirtualRouter" serviceproviderlist[2].service="Dns" serviceproviderlist[2].provider="VirtualRouter" serviceproviderlist[3].service="Firewall" serviceproviderlist[3].provider="VirtualRouter" serviceproviderlist[4].service="Lb" serviceproviderlist[4].provider="VirtualRouter" serviceproviderlist[5].service="UserData" serviceproviderlist[5].provider="VirtualRouter" serviceproviderlist[6].service="SourceNat" serviceproviderlist[6].provider="VirtualRouter" serviceproviderlist[7].service="StaticNat" serviceproviderlist[7].provider="VirtualRouter" serviceproviderlist[8].service="PortForwarding" serviceproviderlist[8].provider="VirtualRouter" serviceCapabilityList[0].service="SourceNat" serviceCapabilityList[0].capabilitytype="RedundantRouter" serviceCapabilityList[0].capabilityvalue="true"


# Isolated Network offerings
cmk -p admin create networkoffering name="acs.net.isolated.core"           displaytext="Isolated Network with Virtual Router"           guestiptype="Isolated" traffictype="Guest" networkrate=500 specifyvlan=false ispersistent=true forvpc=false networkmode="NATTED" conservemode=true egressdefaultpolicy=true ispublic=true enable=true specifyipranges=false supportedservices="Vpn,Dhcp,Dns,Firewall,Lb,UserData,SourceNat,StaticNat,PortForwarding" serviceproviderlist[0].service="Vpn" serviceproviderlist[0].provider="VirtualRouter" serviceproviderlist[1].service="Dhcp" serviceproviderlist[1].provider="VirtualRouter" serviceproviderlist[2].service="Dns" serviceproviderlist[2].provider="VirtualRouter" serviceproviderlist[3].service="Firewall" serviceproviderlist[3].provider="VirtualRouter" serviceproviderlist[4].service="Lb" serviceproviderlist[4].provider="VirtualRouter" serviceproviderlist[5].service="UserData" serviceproviderlist[5].provider="VirtualRouter" serviceproviderlist[6].service="SourceNat" serviceproviderlist[6].provider="VirtualRouter" serviceproviderlist[7].service="StaticNat" serviceproviderlist[7].provider="VirtualRouter" serviceproviderlist[8].service="PortForwarding" serviceproviderlist[8].provider="VirtualRouter"
cmk -p admin create networkoffering name="acs.net.isolated.core-redundant" displaytext="Isolated Network with Redundant Virtual Router" guestiptype="Isolated" traffictype="Guest" networkrate=500 specifyvlan=false ispersistent=true forvpc=false networkmode="NATTED" conservemode=true egressdefaultpolicy=true ispublic=true enable=true specifyipranges=false supportedservices="Vpn,Dhcp,Dns,Firewall,Lb,UserData,SourceNat,StaticNat,PortForwarding" serviceproviderlist[0].service="Vpn" serviceproviderlist[0].provider="VirtualRouter" serviceproviderlist[1].service="Dhcp" serviceproviderlist[1].provider="VirtualRouter" serviceproviderlist[2].service="Dns" serviceproviderlist[2].provider="VirtualRouter" serviceproviderlist[3].service="Firewall" serviceproviderlist[3].provider="VirtualRouter" serviceproviderlist[4].service="Lb" serviceproviderlist[4].provider="VirtualRouter" serviceproviderlist[5].service="UserData" serviceproviderlist[5].provider="VirtualRouter" serviceproviderlist[6].service="SourceNat" serviceproviderlist[6].provider="VirtualRouter" serviceproviderlist[7].service="StaticNat" serviceproviderlist[7].provider="VirtualRouter" serviceproviderlist[8].service="PortForwarding" serviceproviderlist[8].provider="VirtualRouter" serviceCapabilityList[0].service="SourceNat" serviceCapabilityList[0].capabilitytype="RedundantRouter" serviceCapabilityList[0].capabilityvalue="true"


# VPC Network offerings
cmk -p admin create networkoffering name="acs.net.vpc.core-internal-lb" displaytext="VPC Network with VpcVirtualRouter and Internal LB VM" guestiptype="Isolated" traffictype="Guest" networkrate=500 specifyvlan=false ispersistent=true forvpc=true networkmode="NATTED" conservemode=true egressdefaultpolicy=true ispublic=true enable=true specifyipranges=false internetprotocol="IPv4" guestiptype="Isolated" lbtype="internalLb" supportedservices="Vpn,Dhcp,Dns,Lb,UserData,SourceNat,StaticNat,PortForwarding,NetworkACL" serviceproviderlist[0].service="Vpn" serviceproviderlist[0].provider="VpcVirtualRouter" serviceproviderlist[1].service="Dhcp" serviceproviderlist[1].provider="VpcVirtualRouter" serviceproviderlist[2].service="Dns" serviceproviderlist[2].provider="VpcVirtualRouter" serviceproviderlist[3].service="Lb" serviceproviderlist[3].provider="InternalLbVm" serviceproviderlist[4].service="UserData" serviceproviderlist[4].provider="VpcVirtualRouter" serviceproviderlist[5].service="SourceNat" serviceproviderlist[5].provider="VpcVirtualRouter" serviceproviderlist[6].service="StaticNat" serviceproviderlist[6].provider="VpcVirtualRouter" serviceproviderlist[7].service="PortForwarding" serviceproviderlist[7].provider="VpcVirtualRouter"                                  serviceproviderlist[8].service="NetworkACL" serviceproviderlist[8].provider="VpcVirtualRouter" serviceCapabilityList[0].service="SourceNat" serviceCapabilityList[0].capabilitytype="SupportedSourceNatTypes" serviceCapabilityList[0].capabilityvalue="peraccount" serviceCapabilityList[1].service="lb" serviceCapabilityList[1].capabilitytype="SupportedLbIsolation" serviceCapabilityList[1].capabilityvalue="dedicated" serviceCapabilityList[2].service="lb" serviceCapabilityList[2].capabilitytype="lbSchemes"            serviceCapabilityList[2].capabilityvalue="internal"
cmk -p admin create networkoffering name="acs.net.vpc.core-public-lb"   displaytext="VPC Network with VpcVirtualRouter and Public LB"      guestiptype="Isolated" traffictype="Guest" networkrate=500 specifyvlan=false ispersistent=true forvpc=true networkmode="NATTED" conservemode=true egressdefaultpolicy=true ispublic=true enable=true specifyipranges=false internetprotocol="IPv4" guestiptype="Isolated" lbtype="publicLb" vmautoscalingcapability="true" supportedservices="Vpn,Dhcp,Dns,Lb,UserData,SourceNat,StaticNat,PortForwarding,NetworkACL" serviceproviderlist[0].service="Vpn" serviceproviderlist[0].provider="VpcVirtualRouter" serviceproviderlist[1].service="Dhcp" serviceproviderlist[1].provider="VpcVirtualRouter" serviceproviderlist[2].service="Dns" serviceproviderlist[2].provider="VpcVirtualRouter" serviceproviderlist[3].service="Lb" serviceproviderlist[3].provider="VpcVirtualRouter" serviceproviderlist[4].service="UserData" serviceproviderlist[4].provider="VpcVirtualRouter" serviceproviderlist[5].service="SourceNat" serviceproviderlist[5].provider="VpcVirtualRouter" serviceproviderlist[6].service="StaticNat" serviceproviderlist[6].provider="VpcVirtualRouter" serviceproviderlist[7].service="PortForwarding" serviceproviderlist[7].provider="VpcVirtualRouter" serviceproviderlist[8].service="NetworkACL" serviceproviderlist[8].provider="VpcVirtualRouter" serviceCapabilityList[0].service="SourceNat" serviceCapabilityList[0].capabilitytype="SupportedSourceNatTypes" serviceCapabilityList[0].capabilityvalue="peraccount" serviceCapabilityList[1].service="lb" serviceCapabilityList[1].capabilitytype="VmAutoScaling"        serviceCapabilityList[1].capabilityvalue="true"      serviceCapabilityList[2].service="lb" serviceCapabilityList[2].capabilitytype="SupportedLbIsolation" serviceCapabilityList[2].capabilityvalue="dedicated"
```

### VPC Offering

```bash
cmk -p admin create vpcoffering name="acs.vpc.natted.core"           displaytext="NATTED Single Virtual Router VPC with VpcVirtualRouter, ConfigDrive, InternalLbVm"    internetprotocol="IPv4" ispublic=true enable=true networkmode="NATTED" supportedservices="Vpn,Dhcp,Dns,Lb,Gateway,UserData,SourceNat,StaticNat,PortForwarding,NetworkACL" serviceproviderlist[0].service="Vpn" serviceproviderlist[0].provider="VpcVirtualRouter" serviceproviderlist[1].service="Dhcp" serviceproviderlist[1].provider="VpcVirtualRouter" serviceproviderlist[2].service="Dhcp" serviceproviderlist[2].provider="ConfigDrive" serviceproviderlist[3].service="Dns" serviceproviderlist[3].provider="VpcVirtualRouter" serviceproviderlist[4].service="Dns" serviceproviderlist[4].provider="ConfigDrive" serviceproviderlist[5].service="Lb" serviceproviderlist[5].provider="InternalLbVm" serviceproviderlist[6].service="Lb" serviceproviderlist[6].provider="VpcVirtualRouter" serviceproviderlist[7].service="Gateway" serviceproviderlist[7].provider="VpcVirtualRouter" serviceproviderlist[8].service="UserData" serviceproviderlist[8].provider="VpcVirtualRouter" serviceproviderlist[9].service="UserData" serviceproviderlist[9].provider="ConfigDrive" serviceproviderlist[10].service="SourceNat" serviceproviderlist[10].provider="VpcVirtualRouter" serviceproviderlist[11].service="StaticNat" serviceproviderlist[11].provider="VpcVirtualRouter" serviceproviderlist[12].service="PortForwarding" serviceproviderlist[12].provider="VpcVirtualRouter" serviceproviderlist[13].service="NetworkACL" serviceproviderlist[13].provider="VpcVirtualRouter"
cmk -p admin create vpcoffering name="acs.vpc.natted.redundant-core" displaytext="NATTED Redundant Virtual Router VPC with VpcVirtualRouter, ConfigDrive, InternalLbVm" internetprotocol="IPv4" ispublic=true enable=true networkmode="NATTED" supportedservices="Vpn,Dhcp,Dns,Lb,Gateway,UserData,SourceNat,StaticNat,PortForwarding,NetworkACL" serviceproviderlist[0].service="Vpn" serviceproviderlist[0].provider="VpcVirtualRouter" serviceproviderlist[1].service="Dhcp" serviceproviderlist[1].provider="VpcVirtualRouter" serviceproviderlist[2].service="Dhcp" serviceproviderlist[2].provider="ConfigDrive" serviceproviderlist[3].service="Dns" serviceproviderlist[3].provider="VpcVirtualRouter" serviceproviderlist[4].service="Dns" serviceproviderlist[4].provider="ConfigDrive" serviceproviderlist[5].service="Lb" serviceproviderlist[5].provider="InternalLbVm" serviceproviderlist[6].service="Lb" serviceproviderlist[6].provider="VpcVirtualRouter" serviceproviderlist[7].service="Gateway" serviceproviderlist[7].provider="VpcVirtualRouter" serviceproviderlist[8].service="UserData" serviceproviderlist[8].provider="VpcVirtualRouter" serviceproviderlist[9].service="UserData" serviceproviderlist[9].provider="ConfigDrive" serviceproviderlist[10].service="SourceNat" serviceproviderlist[10].provider="VpcVirtualRouter" serviceproviderlist[11].service="StaticNat" serviceproviderlist[11].provider="VpcVirtualRouter" serviceproviderlist[12].service="PortForwarding" serviceproviderlist[12].provider="VpcVirtualRouter" serviceproviderlist[13].service="NetworkACL" serviceproviderlist[13].provider="VpcVirtualRouter" serviceCapabilityList[0].service="SourceNat" serviceCapabilityList[0].capabilitytype="RedundantRouter" serviceCapabilityList[0].capabilityvalue="true"
```

## Templates

```bash
# Variables - Customize these for your environment
ZONE_ID=$(cmk -p admin list zones | jq -r '.zone[0].id')

echo "Registering OS Templates..."

# Ubuntu 24.04 - Noble
echo "Registering Ubuntu 24.04..."
UBUNTU_TEMPLATE_ID=$(cmk -p admin register template \
  displaytext="Ubuntu 24.04 LTS Cloud Image" \
  name="Ubuntu 24.04 - Noble" \
  ostypeid=$(cmk -p admin list ostypes description="Ubuntu 24.04" | jq -r '.ostype[0].id') \
  url="https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img" \
  zoneid="$ZONE_ID" \
  hypervisor=KVM \
  format=QCOW2 \
  ispublic=true \
  isfeatured=true \
  isextractable=false \
  isdynamicallyscalable=true \
  passwordenabled=false \
  | jq -r '.template[0].id')
echo "Ubuntu 24.04 Template ID: $UBUNTU_TEMPLATE_ID"

# Configure Ubuntu template settings
cmk -p admin update template id="$UBUNTU_TEMPLATE_ID" \
  "details[0].keyboard=us" \
  "details[0].video.hardware=qxl" \
  "details[0].video.ram=256" \
  "details[0].guest.cpu.mode=host-passthrough" \
  "details[0].nicAdapter=virtio" \
  "details[0].rootDiskController=scsi"

# Debian 12 - Bookworm
echo "Registering Debian 12..."
DEBIAN_TEMPLATE_ID=$(cmk -p admin register template \
  displaytext="Debian 12 Bookworm" \
  name="Debian 12 - Bookworm" \
  ostypeid=$(cmk -p admin list ostypes description="Debian GNU/Linux 12 (64-bit)" | jq -r '.ostype[0].id') \
  url="https://cdimage.debian.org/images/cloud/bookworm/latest/debian-12-nocloud-amd64.qcow2" \
  zoneid="$ZONE_ID" \
  hypervisor=KVM \
  format=QCOW2 \
  ispublic=true \
  isfeatured=true \
  isextractable=false \
  isdynamicallyscalable=true \
  passwordenabled=false \
  | jq -r '.template[0].id')
echo "Debian 12 Template ID: $DEBIAN_TEMPLATE_ID"

# Configure Debian template settings
cmk -p admin update template id="$DEBIAN_TEMPLATE_ID" \
  "details[0].keyboard=us" \
  "details[0].video.hardware=qxl" \
  "details[0].video.ram=256" \
  "details[0].guest.cpu.mode=host-passthrough" \
  "details[0].nicAdapter=virtio" \
  "details[0].rootDiskController=scsi"

echo "Registering CKS Kubernetes Versions..."

# CKS v1.32.5 - Calico
echo "Registering CKS v1.32.5 Calico..."
cmk -p admin addKubernetesSupportedVersion \
  semanticversion="1.32.5" \
  name="cks-v1.32.5-calico-x86_64" \
  url="https://download.cloudstack.org/cks/setup-v1.32.5-calico-x86_64.iso" \
  zoneid="$ZONE_ID" \
  mincpunumber=2 \
  minmemory=2048

# CKS v1.33.1 - Calico
echo "Registering CKS v1.33.1 Calico..."
cmk -p admin addKubernetesSupportedVersion \
  semanticversion="1.33.1" \
  name="cks-v1.33.1-calico_v3.30.0-x86_64" \
  url="https://download.cloudstack.org/cks/setup-v1.33.1-calico-x86_64.iso" \
  zoneid="$ZONE_ID" \
  mincpunumber=2 \
  minmemory=2048

# CKS v1.34.2 - Calico
echo "Registering CKS v1.34.2 Calico..."
cmk -p admin addKubernetesSupportedVersion \
  semanticversion="1.34.2" \
  name="cks-v1.34.2-calico-x86_64" \
  url="https://nulcell-apache-cks-images.s3.eu-central-1.amazonaws.com/cks-v1.34.2-calico-x86_64.iso" \
  zoneid="$ZONE_ID" \
  mincpunumber=2 \
  minmemory=2048

# CKS v1.34.2 - Cilium
echo "Registering CKS v1.34.2 Cilium..."
cmk -p admin addKubernetesSupportedVersion \
  semanticversion="1.34.2" \
  name="cks-v1.34.2-cilium_v1.18.2-x86_64" \
  url="https://nulcell-apache-cks-images.s3.eu-central-1.amazonaws.com/cks-v1.34.2-cilium-x86_64.iso" \
  zoneid="$ZONE_ID" \
  mincpunumber=2 \
  minmemory=2048

echo "Registering Utility ISOs..."

# VirtIO Drivers for Windows
echo "Registering VirtIO drivers ISO for Windows..."
cmk -p admin register iso \
  displaytext="VirtIO drivers for Windows VMs" \
  name="virtio-win" \
  url="https://fedorapeople.org/groups/virt/virtio-win/direct-downloads/stable-virtio/virtio-win.iso" \
  zoneid="$ZONE_ID" \
  bootable=false \
  ostypeid=$(cmk -p admin list ostypes description="Other (64-bit)" | jq -r '.ostype[0].id')

cmk -p admin list templates templatefilter=all zoneid=$ZONE_ID | jq -r '.template[] | select(.name | contains(\"Ubuntu\") or contains(\"Debian\")) | {name: .name, status: .status}'
cmk -p admin list kubernetessupportedversions zoneid=$ZONE_ID | jq -r '.kubernetessupportedversion[] | {name: .name, version: .semanticversion, state: .state}'
cmk -p admin list isos zoneid=$ZONE_ID | jq -r '.iso[] | {name: .name, isready: .isready}'
echo "Wait for all templates to reach 'Download Complete' status before deploying VMs."
```

## User Data Scripts

```bash
echo "Registering User Data Scripts..."
# Get domain ID for homecloud
HOMECLOUD_DOMAIN_ID=$(cmk -p homecloud-admin list domains name=homecloud | jq -r '.domain[0].id')

# cloud-default user data
echo "Registering cloud-default user data..."
cmk -p homecloud-admin registerUserData \
  name="cloud-default" \
  userdata="$(cat ../compute/cloud-init/cloud-default.yaml | base64)" \
  account=homecloud \
  domainid="$HOMECLOUD_DOMAIN_ID"

# tailscale-router-debian user data
echo "Registering tailscale-router-debian user data..."
cmk -p homecloud-admin registerUserData \
  name="tailscale-router-debian" \
  userdata="$(cat ../compute/cloud-init/tailscale-router-debian.yaml | base64)" \
  account=homecloud \
  domainid="$HOMECLOUD_DOMAIN_ID" \
  "params[0].name=tailscale_auth_key" \
  "params[0].description=Tailscale auth key with subnet router capability" \
  "params[0].required=true" \
  "params[1].name=network_router_cidr" \
  "params[1].description=The CIDR of the network to be routed via Tailscale" \
  "params[1].required=true"

echo "Registering CNI Configurations..."

# Cilium CNI configuration
echo "Registering Cilium CNI configuration..."
cmk -p homecloud-admin registerCniConfiguration \
  name="cilium" \
  description="Cilium CNI configuration for CKS clusters" \
  cniconfig="$(tail -n +3 ../compute/cni-config/cilium.yaml | base64)" \
  account=homecloud \
  domainid="$HOMECLOUD_DOMAIN_ID"

# SSH Key Pair
cmk -p homecloud-admin register sshkeypair \
  name="nulcell" \
  publickey="$(op read "op://homecloud/nulcell/public key")" \
  account=homecloud \
  domainid="$HOMECLOUD_DOMAIN_ID"
```

## VPC

### Dev VPC

```bash
DEV_VPC_NAME="homecloud-vpc-dev"
DEV_VPC_CIDR="10.0.0.0/24"

VPC_OFFERING_ID=$(cmk -p homecloud-admin list vpcofferings name="acs.vpc.natted.core" | jq -r '.vpcoffering[0].id')
PUBLIC_LB_OFFERING_ID=$(cmk -p homecloud-admin list networkofferings name="acs.net.vpc.core-public-lb" | jq -r '.networkoffering[0].id')
INTERNAL_LB_OFFERING_ID=$(cmk -p homecloud-admin list networkofferings name="acs.net.vpc.core-internal-lb" | jq -r '.networkoffering[0].id')

DEV_VPC_ID=$(cmk -p homecloud-admin create vpc \
  name="$DEV_VPC_NAME" \
  displaytext="Development VPC" \
  vpcofferingid="$VPC_OFFERING_ID" \
  cidr="$DEV_VPC_CIDR" \
  zoneid="$ZONE_ID" \
  account="$ACCOUNT_NAME" \
  domainid="$HOMECLOUD_DOMAIN_ID" \
  | jq -r '.vpc.id')

DEV_PUB_NET_1_ID=$(cmk -p homecloud-admin create network \
  name="pub-net-1" \
  displaytext="Development Public Network 1" \
  networkofferingid="$PUBLIC_LB_OFFERING_ID" \
  zoneid="$ZONE_ID" \
  vpcid="$DEV_VPC_ID" \
  gateway="10.0.0.1" \
  netmask="255.255.255.192" \
  account="$ACCOUNT_NAME" \
  domainid="$HOMECLOUD_DOMAIN_ID" \
  aclid=$(cmk -p homecloud-admin list networkacllists name="default_allow" vpcid="$DEV_VPC_ID" | jq -r '.networkacllist[0].id') \
  | jq -r '.network.id')

DEV_PRIV_NET_1_ID=$(cmk -p homecloud-admin create network \
  name="priv-net-1" \
  displaytext="Development Private Network 1" \
  networkofferingid="$INTERNAL_LB_OFFERING_ID" \
  zoneid="$ZONE_ID" \
  vpcid="$DEV_VPC_ID" \
  gateway="10.0.0.65" \
  netmask="255.255.255.192" \
  account="$ACCOUNT_NAME" \
  domainid="$HOMECLOUD_DOMAIN_ID" \
  aclid=$(cmk -p homecloud-admin list networkacllists name="default_allow" vpcid="$DEV_VPC_ID" | jq -r '.networkacllist[0].id') \
  | jq -r '.network.id')

DEV_PRIV_NET_2_ID=$(cmk -p homecloud-admin create network \
  name="priv-net-2" \
  displaytext="Development Private Network 2" \
  networkofferingid="$INTERNAL_LB_OFFERING_ID" \
  zoneid="$ZONE_ID" \
  vpcid="$DEV_VPC_ID" \
  gateway="10.0.0.129" \
  netmask="255.255.255.192" \
  account="$ACCOUNT_NAME" \
  domainid="$HOMECLOUD_DOMAIN_ID" \
  aclid=$(cmk -p homecloud-admin list networkacllists name="default_allow" vpcid="$DEV_VPC_ID" | jq -r '.networkacllist[0].id') \
  | jq -r '.network.id')

DEV_PRIV_NET_3_ID=$(cmk -p homecloud-admin create network \
  name="priv-net-3" \
  displaytext="Development Private Network 3" \
  networkofferingid="$INTERNAL_LB_OFFERING_ID" \
  zoneid="$ZONE_ID" \
  vpcid="$DEV_VPC_ID" \
  gateway="10.0.0.193" \
  netmask="255.255.255.192" \
  account="$ACCOUNT_NAME" \
  domainid="$HOMECLOUD_DOMAIN_ID" \
  aclid=$(cmk -p homecloud-admin list networkacllists name="default_allow" vpcid="$DEV_VPC_ID" | jq -r '.networkacllist[0].id') \
  | jq -r '.network.id')
```

### Prod VPC

```bash
PROD_VPC_NAME="homecloud-vpc-prod"
PROD_VPC_CIDR="10.1.1.0/24"

VPC_OFFERING_ID=$(cmk -p homecloud-admin list vpcofferings name="acs.vpc.natted.redundant-core" | jq -r '.vpcoffering[0].id')
PUBLIC_LB_OFFERING_ID=$(cmk -p homecloud-admin list networkofferings name="acs.net.vpc.core-public-lb" | jq -r '.networkoffering[0].id')
INTERNAL_LB_OFFERING_ID=$(cmk -p homecloud-admin list networkofferings name="acs.net.vpc.core-internal-lb" | jq -r '.networkoffering[0].id')

PROD_VPC_ID=$(cmk -p homecloud-admin create vpc \
  name="$PROD_VPC_NAME" \
  displaytext="Production VPC" \
  vpcofferingid="$VPC_OFFERING_ID" \
  cidr="$PROD_VPC_CIDR" \
  zoneid="$ZONE_ID" \
  account="$ACCOUNT_NAME" \
  domainid="$HOMECLOUD_DOMAIN_ID" \
  | jq -r '.vpc.id')

PROD_PUB_NET_1_ID=$(cmk -p homecloud-admin create network \
  name="pub-net-1" \
  displaytext="Production Public Network 1" \
  networkofferingid="$PUBLIC_LB_OFFERING_ID" \
  zoneid="$ZONE_ID" \
  vpcid="$PROD_VPC_ID" \
  gateway="10.1.1.1" \
  netmask="255.255.255.192" \
  account="$ACCOUNT_NAME" \
  domainid="$HOMECLOUD_DOMAIN_ID" \
  aclid=$(cmk -p homecloud-admin list networkacllists name="default_allow" vpcid="$PROD_VPC_ID" | jq -r '.networkacllist[0].id') \
  | jq -r '.network.id')

PROD_PRIV_NET_1_ID=$(cmk -p homecloud-admin create network \
  name="priv-net-1" \
  displaytext="Production Private Network 1" \
  networkofferingid="$INTERNAL_LB_OFFERING_ID" \
  zoneid="$ZONE_ID" \
  vpcid="$PROD_VPC_ID" \
  gateway="10.1.1.65" \
  netmask="255.255.255.192" \
  account="$ACCOUNT_NAME" \
  domainid="$HOMECLOUD_DOMAIN_ID" \
  aclid=$(cmk -p homecloud-admin list networkacllists name="default_allow" vpcid="$PROD_VPC_ID" | jq -r '.networkacllist[0].id') \
  | jq -r '.network.id')

PROD_PRIV_NET_2_ID=$(cmk -p homecloud-admin create network \
  name="priv-net-2" \
  displaytext="Production Private Network 2" \
  networkofferingid="$INTERNAL_LB_OFFERING_ID" \
  zoneid="$ZONE_ID" \
  vpcid="$PROD_VPC_ID" \
  gateway="10.1.1.129" \
  netmask="255.255.255.192" \
  account="$ACCOUNT_NAME" \
  domainid="$HOMECLOUD_DOMAIN_ID" \
  aclid=$(cmk list networkacllists name="default_allow" vpcid="$PROD_VPC_ID" | jq -r '.networkacllist[0].id') \
  | jq -r '.network.id')

PROD_PRIV_NET_3_ID=$(cmk -p homecloud-admin create network \
  name="priv-net-3" \
  displaytext="Production Private Network 3" \
  networkofferingid="$INTERNAL_LB_OFFERING_ID" \
  zoneid="$ZONE_ID" \
  vpcid="$PROD_VPC_ID" \
  gateway="10.1.1.193" \
  netmask="255.255.255.192" \
  account="$ACCOUNT_NAME" \
  domainid="$HOMECLOUD_DOMAIN_ID" \
  aclid=$(cmk -p homecloud-admin list networkacllists name="default_allow" vpcid="$PROD_VPC_ID" | jq -r '.networkacllist[0].id') \
  | jq -r '.network.id')
```

## Isolated Network

```bash
ISOLATED_NETWORK_NAME="isolated-net-1"
ISOLATED_NETWORK_CIDR="10.2.2.0/24"

ISOLATED_OFFERING_ID=$(cmk -p homecloud-admin list networkofferings name="acs.net.isolated.core" | jq -r '.networkoffering[0].id')

ISOLATED_NETWORK_ID=$(cmk -p homecloud-admin create network \
  name="$ISOLATED_NETWORK_NAME" \
  displaytext="Isolated Network for Testing" \
  networkofferingid="$ISOLATED_OFFERING_ID" \
  zoneid="$ZONE_ID" \
  gateway="10.2.2.1" \
  netmask="255.255.255.0" \
  account="homecloud" \
  domainid="$HOMECLOUD_DOMAIN_ID" \
  | jq -r '.network.id')
```

## VPN

```bash
TAILSCALE_AUTH_KEY="tskey-auth-xxxxxx-xxxxxxxxxxxxxxx"  # Replace with actual reusable ephemeral Tailscale auth key
TAILSCALE_USERDATA_ID=$(cmk -p homecloud-admin list userdata name="tailscale-router-debian" account="homecloud" domainid="$HOMECLOUD_DOMAIN_ID" | jq -r '.userdata[0].id')
UBUNTU_TEMPLATE_ID=$(cmk -p homecloud-admin list templates templatefilter=all name="Ubuntu 24.04 - Noble" zoneid="$ZONE_ID" | jq -r '.template[0].id')
COMPUTE_OFFERING_ID=$(cmk -p homecloud-admin list serviceofferings name="acs.comp.gen.small" | jq -r '.serviceoffering[0].id')
```

### Dev VPN

```bash
DEV_VPC_CIDR="10.0.0.0/24"

DEV_ROUTER_VM_ID=$(cmk -p homecloud-admin deploy virtualmachine \
  name="tailscale-router-dev" \
  displayname="Development Tailscale Router" \
  serviceofferingid="$COMPUTE_OFFERING_ID" \
  templateid="$UBUNTU_TEMPLATE_ID" \
  zoneid="$ZONE_ID" \
  networkids="$DEV_PUB_NET_1_ID,$DEV_PRIV_NET_1_ID,$DEV_PRIV_NET_2_ID,$DEV_PRIV_NET_3_ID" \
  account="homecloud" \
  domainid="$HOMECLOUD_DOMAIN_ID" \
  userdataid="$TAILSCALE_USERDATA_ID" \
  "userdatadetails[0].tailscale_auth_key=$TAILSCALE_AUTH_KEY" \
  "userdatadetails[0].network_router_cidr=$DEV_VPC_CIDR" \
  keypair="nulcell" \
  | jq -r '.virtualmachine.id')
```

### Prod VPN

```bash
PROD_VPC_CIDR="10.1.1.0/24"

PROD_ROUTER_VM_ID=$(cmk -p homecloud-admin deploy virtualmachine \
  name="tailscale-router-prod" \
  displayname="Production Tailscale Router" \
  serviceofferingid="$COMPUTE_OFFERING_ID" \
  templateid="$UBUNTU_TEMPLATE_ID" \
  zoneid="$ZONE_ID" \
  networkids="$PROD_PUB_NET_1_ID,$PROD_PRIV_NET_1_ID,$PROD_PRIV_NET_2_ID,$PROD_PRIV_NET_3_ID" \
  account="homecloud" \
  domainid="$HOMECLOUD_DOMAIN_ID" \
  userdataid="$TAILSCALE_USERDATA_ID" \
  "userdatadetails[0].tailscale_auth_key=$TAILSCALE_AUTH_KEY" \
  "userdatadetails[0].network_router_cidr=$PROD_VPC_CIDR" \
  keypair="nulcell" \
  | jq -r '.virtualmachine.id')
```

## Kubernetes Cluster

```bash
CKS_OFFERING_ID=$(cmk -p homecloud-admin list kubernetessupportedversions name="cks-v1.34.2-cilium_v1.18.2-x86_64" zoneid="$ZONE_ID" | jq -r '.kubernetessupportedversion[0].id')
```

### Dev CKS Cluster

```bash
echo "Creating Development CKS Cluster (this takes 15-30 minutes)..."
CKS_SERVICE_OFFERING_ID=$(cmk -p homecloud-admin list serviceofferings name="acs.comp.mem.medium" | jq -r '.serviceoffering[0].id')
DEV_CKS_ID=$(cmk -p homecloud-admin create kubernetescluster \
  name="homecloud-cks-dev" \
  description="Development Kubernetes Cluster" \
  zoneid="$ZONE_ID" \
  kubernetesversionid="$CKS_OFFERING_ID" \
  serviceofferingid="$CKS_SERVICE_OFFERING_ID" \
  noderootdisksize=50 \
  networkid="$DEV_PUB_NET_1_ID" \
  account="$ACCOUNT_NAME" \
  domainid="$HOMECLOUD_DOMAIN_ID" \
  masternodes=1 \
  size=1 \
  keypair="nulcell" \
  | jq -r '.kubernetescluster.id')
echo "Development CKS Cluster ID: $DEV_CKS_ID"
```

### Prod CKS Cluster

```bash
echo "Creating Production CKS Cluster (this takes 15-30 minutes)..."
CKS_SERVICE_OFFERING_ID=$(cmk -p homecloud-admin list serviceofferings name="acs.comp.mem.large" | jq -r '.serviceoffering[0].id')
PROD_CKS_ID=$(cmk -p homecloud-admin create kubernetescluster \
  name="homecloud-cks-prod" \
  description="Production Kubernetes Cluster" \
  zoneid="$ZONE_ID" \
  kubernetesversionid="$CKS_OFFERING_ID" \
  serviceofferingid="$CKS_SERVICE_OFFERING_ID" \
  noderootdisksize=50 \
  networkid="$PROD_PUB_NET_1_ID" \
  account="$ACCOUNT_NAME" \
  domainid="$HOMECLOUD_DOMAIN_ID" \
  masternodes=1 \
  size=3 \
  keypair="homecloud-admin" \
  | jq -r '.kubernetescluster.id')
echo "Production CKS Cluster ID: $PROD_CKS_ID"
```
