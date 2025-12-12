# Cloudmonkey CLI Setup

**TODO**: Create the equivalent using Terraform CloudStack provider where possible.

**Note**: When creating the network interfaces for the hosts, ensure that the `cloudbr0` and `cloudbr1` bridges are used against interfaces with the name format of `enp<id>s0`, e.g. `enp3s0`, `enp4s0`, etc. If this is not done, CloudStack may run into VLAN issues.

## Cloudmonkey Profile Configuration

### Admin User

```bash
cmk set profile admin
cmk set url http://acs-node-0.nulcell.com:8080/client/api
cmk set username $(op read "op://homecloud/CloudStack - admin/username")
cmk set password $(op read "op://homecloud/CloudStack - admin/password")
cmk set domain /
cmk set timeout 3600
cmk set asyncblock true
cmk set output json
cmk -p admin sync
```

### Account Setup

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

echo "Updating account resouce limits..."
DOMAIN_ID=$(cmk -p admin list domains name="$DOMAIN_NAME" | jq -r '.domain[0].id')
# 0 - Instance. Number of instances a user can create.
cmk -p admin updateResourceLimit \
  account="$ACCOUNT_NAME" \
  domainid="$DOMAIN_ID" \
  resourcetype=0 \
  max=40
# 1 - IP. Number of public IP addresses an account can own.
cmk -p admin updateResourceLimit \
  account="$ACCOUNT_NAME" \
  domainid="$DOMAIN_ID" \
  resourcetype=1 \
  max=40
# 2 - Volume. Number of disk volumes an account can own.
cmk -p admin updateResourceLimit \
  account="$ACCOUNT_NAME" \
  domainid="$DOMAIN_ID" \
  resourcetype=2 \
  max=100
# 3 - Snapshot. Number of snapshots an account can own.
cmk -p admin updateResourceLimit \
  account="$ACCOUNT_NAME" \
  domainid="$DOMAIN_ID" \
  resourcetype=3 \
  max=100
# 4 - Template. Number of templates an account can register/create.
cmk -p admin updateResourceLimit \
  account="$ACCOUNT_NAME" \
  domainid="$DOMAIN_ID" \
  resourcetype=4 \
  max=40
# 5 - Project. Number of projects an account can own.
cmk -p admin updateResourceLimit \
  account="$ACCOUNT_NAME" \
  domainid="$DOMAIN_ID" \
  resourcetype=5 \
  max=5
# 6 - Network. Number of networks an account can own.
cmk -p admin updateResourceLimit \
  account="$ACCOUNT_NAME" \
  domainid="$DOMAIN_ID" \
  resourcetype=6 \
  max=20
# 7 - VPC. Number of VPC an account can own.
cmk -p admin updateResourceLimit \
  account="$ACCOUNT_NAME" \
  domainid="$DOMAIN_ID" \
  resourcetype=7 \
  max=4
# 8 - CPU. Number of CPU an account can allocate for their resources.
cmk -p admin updateResourceLimit \
  account="$ACCOUNT_NAME" \
  domainid="$DOMAIN_ID" \
  resourcetype=8 \
  max=110 # Assuming 2.5GHz per vCPU with a cluster of real 234.59GHz (with overprovisioning of 1.25), this allows for ~117 vCPUs.
# 9 - Memory. Amount of RAM an account can allocate for their resources.
cmk -p admin updateResourceLimit \
  account="$ACCOUNT_NAME" \
  domainid="$DOMAIN_ID" \
  resourcetype=9 \
  max=148480 # In MiB, assuming a cluster with 116GiB RAM and overprovisioning of 1.25, this allows for ~145GiB RAM.
# 10 - PrimaryStorage. Total primary storage space (in GiB) a user can use.
cmk -p admin updateResourceLimit \
  account="$ACCOUNT_NAME" \
  domainid="$DOMAIN_ID" \
  resourcetype=10 \
  max=2000
# 11 - SecondaryStorage. Total secondary storage space (in GiB) a user can use.
cmk -p admin updateResourceLimit \
  account="$ACCOUNT_NAME" \
  domainid="$DOMAIN_ID" \
  resourcetype=11 \
  max=2000
# 12 - Backups. Number of backups an account can own.
cmk -p admin updateResourceLimit \
  account="$ACCOUNT_NAME" \
  domainid="$DOMAIN_ID" \
  resourcetype=12 \
  max=50
# 13 - Backup Storage (GiB)
cmk -p admin updateResourceLimit \
  account="$ACCOUNT_NAME" \
  domainid="$DOMAIN_ID" \
  resourcetype=13 \
  max=1000
# 14 - Buckets
cmk -p admin updateResourceLimit \
  account="$ACCOUNT_NAME" \
  domainid="$DOMAIN_ID" \
  resourcetype=14 \
  max=0
# 15 - Object Storage (GiB)
cmk -p admin updateResourceLimit \
  account="$ACCOUNT_NAME" \
  domainid="$DOMAIN_ID" \
  resourcetype=15 \
  max=0
# 16 - GPUs
cmk -p admin updateResourceLimit \
  account="$ACCOUNT_NAME" \
  domainid="$DOMAIN_ID" \
  resourcetype=16 \
  max=2
echo "Account resource limits updated."
```

### HomeCloud Admin User

Note: Ensure the `homecloud-admin` user and `/homecloud` domain are created via the CloudStack UI before running these commands.

```bash
cmk set profile homecloud-admin
cmk set url http://acs-node-0.nulcell.com:8080/client/api
cmk set username $(op read "op://homecloud/CloudStack - homecloud-admin/username")
cmk set password $(op read "op://homecloud/CloudStack - homecloud-admin/password")
cmk set domain /homecloud
cmk set timeout 3600
cmk set asyncblock true
cmk set output json
cmk -p homecloud-admin sync
```

## Global Settings

```bash
# Variables
ENDPOINT_URL="http://10.10.17.5:8080/client/api"  # Replace with your management server URL

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
cmk -p admin update configuration name=cpu.overprovisioning.factor value=1.25
cmk -p admin update configuration name=vm.min.cpu.speed.equals.cpu.speed.divided.by.cpu.overprovisioning.factor value=false
cmk -p admin update configuration name=vm.min.memory.equals.memory.divided.by.mem.overprovisioning.factor value=false
cmk -p admin update configuration name=vm.serviceoffering.cpu.cores.max value=16
cmk -p admin update configuration name=vm.serviceoffering.ram.size.max value=32768
cmk -p admin update configuration name=user.vm.readonly.details value=""
cmk -p admin update configuration name=user.vm.denied.details value="cpuOvercommitRatio,memoryOvercommitRatio"
# Compute - Kubernetes Settings
cmk -p admin update configuration name=cloud.kubernetes.cluster.experimental.features.enabled value=true
cmk -p admin update configuration name=cloud.kubernetes.cluster.network.offering value="acs.net.isolated.core"

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

# Infrastructure - Primary Storage
cmk -p admin update configuration name=storage.overprovisioning.factor value=2

# Miscellaneous
cmk -p admin update configuration name=endpoint.url value="$ENDPOINT_URL"
cmk -p admin update configuration name=store.download.follow.redirects value=true
cmk -p admin update configuration name=mem.overprovisioning.factor value=1.25 # Be cautious with overprovisioning memory on hosts with low RAM
echo "Global configuration completed."
```

## Zone Setup

**Note**: Since, this is a one time setup, it may be better to simply use the CloudStack UI for this step.

```bash
# Variables
ZONE_NAME="zone-homecloud"
DNS1="10.10.31.254"
DNS2="8.8.8.8"
INTERNAL_DNS1="10.10.31.254"
GUEST_CIDR="10.0.0.0/24"
NETWORK_DOMAIN="homecloud.internal"

# Physical Networks
PHYS_NET_1="cloudbr0"
PHYS_NET_2="cloudbr1"

# Public IP Range (for cloudbr1)
PUBLIC_GATEWAY="10.10.31.254"
PUBLIC_NETMASK="255.255.240.0"
PUBLIC_VLAN="vlan://untagged"
PUBLIC_START_IP="10.10.20.1"
PUBLIC_END_IP="10.10.20.254"

# Pod Configuration
POD_NAME="pod-homecloud"
POD_GATEWAY="10.10.31.254"
POD_NETMASK="255.255.240.0"
POD_START_IP="10.10.21.1"
POD_END_IP="10.10.21.254"

# Guest Traffic VLAN Range
GUEST_VLAN_START="500"
GUEST_VLAN_END="700"

# Cluster Configuration
CLUSTER_NAME="cluster-homecloud"
HYPERVISOR="KVM"

# Host Configuration
HOST_1_IP="10.10.17.5"
HOST_2_IP="10.10.17.10"
HOST_USERNAME="root"

# Primary Storage (NFS)
PRIMARY_STORAGE_NAME="primary-nfs-zone-homecloud"
PRIMARY_STORAGE_SERVER="10.10.17.10"
PRIMARY_STORAGE_PATH="/export/primary"

# Secondary Storage (NFS)
SECONDARY_STORAGE_NAME="secondary-nfs-zone-homecloud"
SECONDARY_STORAGE_SERVER="10.10.17.10"
SECONDARY_STORAGE_PATH="/export/secondary"

echo "Creating Advanced Zone: $ZONE_NAME..."
ZONE_ID=$(cmk -p admin create zone \
  name="$ZONE_NAME" \
  dns1="$DNS1" \
  dns2="$DNS2" \
  internaldns1="$INTERNAL_DNS1" \
  networktype="Advanced" \
  guestcidraddress="$GUEST_CIDR" \
  domain="$NETWORK_DOMAIN" \
  localstorageenabled=true \
  localstorageenabledforsystemvm=false \
  | jq -r '.zone.id')
echo "Zone created with ID: $ZONE_ID"

# Create Physical Network 1 (cloudbr0) for Management
echo "Creating physical network: $PHYS_NET_1..."
PHYS_NET_1_ID=$(cmk -p admin create physicalnetwork \
  name="$PHYS_NET_1" \
  zoneid="$ZONE_ID" \
  isolationmethods="VLAN" \
  | jq -r '.physicalnetwork.id')
echo "Physical network $PHYS_NET_1 created with ID: $PHYS_NET_1_ID"

# Add Management traffic to cloudbr0
echo "Adding Management traffic type to $PHYS_NET_1..."
cmk -p admin add traffictype \
  physicalnetworkid="$PHYS_NET_1_ID" \
  traffictype="Management" \
  kvmnetworklabel="$PHYS_NET_1"

# Enable Physical Network 1
echo "Enabling physical network: $PHYS_NET_1..."
cmk -p admin update physicalnetwork \
  id="$PHYS_NET_1_ID" \
  state="Enabled"

# Get and enable network service providers for Physical Network 1
echo "Configuring network service providers for $PHYS_NET_1..."
cmk -p admin list networkserviceproviders physicalnetworkid="$PHYS_NET_1_ID" | jq -r '.networkserviceprovider[] | "\(.id)|\(.name)"' | while IFS='|' read -r PROVIDER_ID PROVIDER_NAME; do
  if [ -n "$PROVIDER_ID" ]; then
    echo "Processing provider: $PROVIDER_NAME (ID: $PROVIDER_ID)"
    
    # Configure VirtualRouter element before enabling
    if [ "$PROVIDER_NAME" = "VirtualRouter" ]; then
      VR_ELEMENT_ID=$(cmk -p admin list virtualrouterelements nspid="$PROVIDER_ID" | jq -r '.virtualrouterelement[0].id')
      if [ -n "$VR_ELEMENT_ID" ] && [ "$VR_ELEMENT_ID" != "null" ]; then
        echo "  Configuring VirtualRouter element: $VR_ELEMENT_ID"
        cmk -p admin configure virtualrouterelement id="$VR_ELEMENT_ID" enabled=true
      fi
    fi
    
    # Configure InternalLbVm element before enabling
    if [ "$PROVIDER_NAME" = "InternalLbVm" ]; then
      ILB_ELEMENT_ID=$(cmk -p admin list internalloadbalancerelements nspid="$PROVIDER_ID" | jq -r '.internalloadbalancerelement[0].id')
      if [ -n "$ILB_ELEMENT_ID" ] && [ "$ILB_ELEMENT_ID" != "null" ]; then
        echo "  Configuring InternalLbVm element: $ILB_ELEMENT_ID"
        cmk -p admin configure internalloadbalancerelement id="$ILB_ELEMENT_ID" enabled=true
      fi
    fi
    
    # Configure VpcVirtualRouter element before enabling
    if [ "$PROVIDER_NAME" = "VpcVirtualRouter" ]; then
      VPC_VR_ELEMENT_ID=$(cmk -p admin list virtualrouterelements nspid="$PROVIDER_ID" | jq -r '.virtualrouterelement[0].id')
      if [ -n "$VPC_VR_ELEMENT_ID" ] && [ "$VPC_VR_ELEMENT_ID" != "null" ]; then
        echo "  Configuring VpcVirtualRouter element: $VPC_VR_ELEMENT_ID"
        cmk -p admin configure virtualrouterelement id="$VPC_VR_ELEMENT_ID" enabled=true
      fi
    fi
    
    # Now enable the provider
    echo "  Enabling provider: $PROVIDER_NAME"
    cmk -p admin update networkserviceprovider id="$PROVIDER_ID" state="Enabled" || echo "  Warning: Could not enable $PROVIDER_NAME (may not be applicable for this network type)"
  fi
done

# Create Physical Network 2 (cloudbr1) for Public and Guest
echo "Creating physical network: $PHYS_NET_2..."
PHYS_NET_2_ID=$(cmk -p admin create physicalnetwork \
  name="$PHYS_NET_2" \
  zoneid="$ZONE_ID" \
  isolationmethods="VLAN" \
  | jq -r '.physicalnetwork.id')
echo "Physical network $PHYS_NET_2 created with ID: $PHYS_NET_2_ID"

# Add Public traffic to cloudbr1
echo "Adding Public traffic type to $PHYS_NET_2..."
cmk -p admin add traffictype \
  physicalnetworkid="$PHYS_NET_2_ID" \
  traffictype="Public" \
  kvmnetworklabel="$PHYS_NET_2"

# Add public IP range to cloudbr1
echo "Adding public IP range..."
cmk -p admin create vlaniprange \
  zoneid="$ZONE_ID" \
  physicalnetworkid="$PHYS_NET_2_ID" \
  gateway="$PUBLIC_GATEWAY" \
  netmask="$PUBLIC_NETMASK" \
  startip="$PUBLIC_START_IP" \
  endip="$PUBLIC_END_IP" \
  forvirtualnetwork=true \
  vlan="$PUBLIC_VLAN"
echo "Public IP range added: $PUBLIC_START_IP - $PUBLIC_END_IP"

# Add Guest traffic to cloudbr1
echo "Adding Guest traffic type to $PHYS_NET_2..."
cmk -p admin add traffictype \
  physicalnetworkid="$PHYS_NET_2_ID" \
  traffictype="Guest" \
  kvmnetworklabel="$PHYS_NET_2"

# Configure Guest VLAN Range
echo "Configuring guest VLAN range: $GUEST_VLAN_START-$GUEST_VLAN_END..."
cmk -p admin update physicalnetwork \
  id="$PHYS_NET_2_ID" \
  vlan="$GUEST_VLAN_START-$GUEST_VLAN_END"
echo "Guest VLAN range configured"

# Enable Physical Network 2
echo "Enabling physical network: $PHYS_NET_2..."
cmk -p admin update physicalnetwork \
  id="$PHYS_NET_2_ID" \
  state="Enabled"

# Get and enable network service providers for Physical Network 2
echo "Configuring network service providers for $PHYS_NET_2..."
cmk -p admin list networkserviceproviders physicalnetworkid="$PHYS_NET_2_ID" | jq -r '.networkserviceprovider[] | "\(.id)|\(.name)"' | while IFS='|' read -r PROVIDER_ID PROVIDER_NAME; do
  if [ -n "$PROVIDER_ID" ]; then
    echo "Processing provider: $PROVIDER_NAME (ID: $PROVIDER_ID)"
    
    # Configure VirtualRouter element before enabling
    if [ "$PROVIDER_NAME" = "VirtualRouter" ]; then
      VR_ELEMENT_ID=$(cmk -p admin list virtualrouterelements nspid="$PROVIDER_ID" | jq -r '.virtualrouterelement[0].id')
      if [ -n "$VR_ELEMENT_ID" ] && [ "$VR_ELEMENT_ID" != "null" ]; then
        echo "  Configuring VirtualRouter element: $VR_ELEMENT_ID"
        cmk -p admin configure virtualrouterelement id="$VR_ELEMENT_ID" enabled=true
      fi
    fi
    
    # Configure InternalLbVm element before enabling
    if [ "$PROVIDER_NAME" = "InternalLbVm" ]; then
      ILB_ELEMENT_ID=$(cmk -p admin list internalloadbalancerelements nspid="$PROVIDER_ID" | jq -r '.internalloadbalancerelement[0].id')
      if [ -n "$ILB_ELEMENT_ID" ] && [ "$ILB_ELEMENT_ID" != "null" ]; then
        echo "  Configuring InternalLbVm element: $ILB_ELEMENT_ID"
        cmk -p admin configure internalloadbalancerelement id="$ILB_ELEMENT_ID" enabled=true
      fi
    fi
    
    # Configure VpcVirtualRouter element before enabling
    if [ "$PROVIDER_NAME" = "VpcVirtualRouter" ]; then
      VPC_VR_ELEMENT_ID=$(cmk -p admin list virtualrouterelements nspid="$PROVIDER_ID" | jq -r '.virtualrouterelement[0].id')
      if [ -n "$VPC_VR_ELEMENT_ID" ] && [ "$VPC_VR_ELEMENT_ID" != "null" ]; then
        echo "  Configuring VpcVirtualRouter element: $VPC_VR_ELEMENT_ID"
        cmk -p admin configure virtualrouterelement id="$VPC_VR_ELEMENT_ID" enabled=true
      fi
    fi
    
    # Now enable the provider
    echo "  Enabling provider: $PROVIDER_NAME"
    cmk -p admin update networkserviceprovider id="$PROVIDER_ID" state="Enabled" || echo "  Warning: Could not enable $PROVIDER_NAME (may not be applicable for this network type)"
  fi
done

# Create Pod
echo "Creating pod: $POD_NAME..."
POD_ID=$(cmk -p admin create pod \
  name="$POD_NAME" \
  zoneid="$ZONE_ID" \
  gateway="$POD_GATEWAY" \
  netmask="$POD_NETMASK" \
  startip="$POD_START_IP" \
  endip="$POD_END_IP" \
  | jq -r '.pod.id')
echo "Pod created with ID: $POD_ID"

# Create Cluster
echo "Creating cluster: $CLUSTER_NAME..."
CLUSTER_ID=$(cmk -p admin add cluster \
  clustername="$CLUSTER_NAME" \
  clustertype="CloudManaged" \
  hypervisor="$HYPERVISOR" \
  zoneid="$ZONE_ID" \
  podid="$POD_ID" \
  | jq -r '.cluster[0].id')
echo "Cluster created with ID: $CLUSTER_ID"

# Add Host
echo "Adding host: $HOST_1_IP..."
cmk -p admin add host \
  zoneid="$ZONE_ID" \
  podid="$POD_ID" \
  clusterid="$CLUSTER_ID" \
  hypervisor="$HYPERVISOR" \
  url="http://$HOST_1_IP" \
  username="$HOST_USERNAME"
echo "Host added"

echo "Adding host: $HOST_2_IP..."
cmk -p admin add host \
  zoneid="$ZONE_ID" \
  podid="$POD_ID" \
  clusterid="$CLUSTER_ID" \
  hypervisor="$HYPERVISOR" \
  url="http://$HOST_2_IP" \
  username="$HOST_USERNAME"
echo "Host added"

# Create Primary Storage (Zone-wide NFS)
echo "Creating primary storage: $PRIMARY_STORAGE_NAME..."
PRIMARY_STORAGE_ID=$(cmk -p admin create storagepool \
  name="$PRIMARY_STORAGE_NAME" \
  scope="ZONE" \
  zoneid="$ZONE_ID" \
  provider="DefaultPrimary" \
  hypervisor="$HYPERVISOR" \
  url="nfs://$PRIMARY_STORAGE_SERVER$PRIMARY_STORAGE_PATH" \
  | jq -r '.storagepool.id')
echo "Primary storage created with ID: $PRIMARY_STORAGE_ID"

# Add Secondary Storage (Image Store)
echo "Adding secondary storage: $SECONDARY_STORAGE_NAME..."
SECONDARY_STORAGE_ID=$(cmk -p admin add imagestore \
  name="$SECONDARY_STORAGE_NAME" \
  provider="NFS" \
  zoneid="$ZONE_ID" \
  url="nfs://$SECONDARY_STORAGE_SERVER$SECONDARY_STORAGE_PATH" \
  | jq -r '.imagestore.id')
echo "Secondary storage added with ID: $SECONDARY_STORAGE_ID"

# Enable Zone
echo "Enabling zone: $ZONE_NAME..."
cmk -p admin update zone \
  id="$ZONE_ID" \
  allocationstate="Enabled"
echo "Zone enabled successfully"

# Verification
echo ""
echo "=== Zone Setup Complete ==="
echo "Verifying configuration..."
echo ""
echo "Zone:"
cmk -p admin list zones id="$ZONE_ID" | jq -r '.zone[] | "  Name: \(.name), ID: \(.id), State: \(.allocationstate)"'
echo ""
echo "Pods:"
cmk -p admin list pods zoneid="$ZONE_ID" | jq -r '.pod[] | "  Name: \(.name), ID: \(.id)"'
echo ""
echo "Clusters:"
cmk -p admin list clusters zoneid="$ZONE_ID" | jq -r '.cluster[] | "  Name: \(.name), ID: \(.id), Hypervisor: \(.hypervisortype)"'
echo ""
echo "Hosts:"
cmk -p admin list hosts zoneid="$ZONE_ID" | jq -r '.host[] | "  Name: \(.name), ID: \(.id), State: \(.state), Type: \(.type)"'
echo ""
echo "Primary Storage:"
cmk -p admin list storagepools zoneid="$ZONE_ID" | jq -r '.storagepool[] | "  Name: \(.name), ID: \(.id), Type: \(.type), State: \(.state)"'
echo ""
echo "Secondary Storage:"
cmk -p admin list imagestores zoneid="$ZONE_ID" | jq -r '.imagestore[] | "  Name: \(.name), ID: \(.id), Provider: \(.providername)"'
echo ""
echo "Zone setup completed successfully."
```

**Note**: After running the above script, run the following on each host to complete setup:

```bash
sudo systemctl unmask libvirtd.socket libvirtd-ro.socket libvirtd-admin.socket libvirtd-tls.socket libvirtd-tcp.socket
sudo systemctl stop libvirtd; sudo systemctl start libvirtd-tls.socket; sudo systemctl enable libvirtd-tls.socket
sudo service cloudstack-agent restart
sudo reboot now
```

## Service Offerings

### Compute Offering

```bash
cmk -p admin create serviceoffering name="acs.comp.gen.tiny"    displaytext="General Purpose Tiny"      cpunumber=1  cpuspeed=1000 memory=512   networkrate=100 offerha=true  dynamicscalingenabled=true limitcpuuse=true isvolatile=false deploymentplanner="UserDispersingPlanner" ispublic=true storagetype="shared" provisioningtype="thin" diskofferingstrictness=false rootdisksize=20  encryptroot=false purgeresources=true
cmk -p admin create serviceoffering name="acs.comp.gen.small"   displaytext="General Purpose Small"     cpunumber=1  cpuspeed=2500 memory=1024  networkrate=200 offerha=true  dynamicscalingenabled=true limitcpuuse=true isvolatile=false deploymentplanner="UserDispersingPlanner" ispublic=true storagetype="shared" provisioningtype="thin" diskofferingstrictness=false rootdisksize=30  encryptroot=false purgeresources=true
cmk -p admin create serviceoffering name="acs.comp.gen.medium"  displaytext="General Purpose Medium"    cpunumber=2  cpuspeed=2500 memory=2048  networkrate=300 offerha=true  dynamicscalingenabled=true limitcpuuse=true isvolatile=false deploymentplanner="UserDispersingPlanner" ispublic=true storagetype="shared" provisioningtype="thin" diskofferingstrictness=false rootdisksize=50  encryptroot=false purgeresources=true
cmk -p admin create serviceoffering name="acs.comp.gen.large"   displaytext="General Purpose Large"     cpunumber=4  cpuspeed=2500 memory=4096  networkrate=500 offerha=true  dynamicscalingenabled=true limitcpuuse=true isvolatile=false deploymentplanner="UserDispersingPlanner" ispublic=true storagetype="shared" provisioningtype="thin" diskofferingstrictness=false rootdisksize=100 encryptroot=false purgeresources=true
cmk -p admin create serviceoffering name="acs.comp.gen.xlarge"  displaytext="General Purpose xLarge"    cpunumber=8  cpuspeed=2500 memory=8192  networkrate=500 offerha=true  dynamicscalingenabled=true limitcpuuse=true isvolatile=false deploymentplanner="UserDispersingPlanner" ispublic=true storagetype="shared" provisioningtype="thin" diskofferingstrictness=false rootdisksize=100 encryptroot=false purgeresources=true
cmk -p admin create serviceoffering name="acs.comp.gen.2xlarge" displaytext="General Purpose 2xLarge"   cpunumber=16 cpuspeed=2500 memory=16384 networkrate=500 offerha=true  dynamicscalingenabled=true limitcpuuse=true isvolatile=false deploymentplanner="UserDispersingPlanner" ispublic=true storagetype="shared" provisioningtype="thin" diskofferingstrictness=false rootdisksize=100 encryptroot=false purgeresources=true
cmk -p admin create serviceoffering name="acs.comp.mem.small"   displaytext="Memory Optimized Small"    cpunumber=1  cpuspeed=2500 memory=2048  networkrate=200 offerha=true  dynamicscalingenabled=true limitcpuuse=true isvolatile=false deploymentplanner="UserDispersingPlanner" ispublic=true storagetype="shared" provisioningtype="thin" diskofferingstrictness=false rootdisksize=30  encryptroot=false purgeresources=true
cmk -p admin create serviceoffering name="acs.comp.mem.medium"  displaytext="Memory Optimized Medium"   cpunumber=2  cpuspeed=2500 memory=4096  networkrate=300 offerha=true  dynamicscalingenabled=true limitcpuuse=true isvolatile=false deploymentplanner="UserDispersingPlanner" ispublic=true storagetype="shared" provisioningtype="thin" diskofferingstrictness=false rootdisksize=50  encryptroot=false purgeresources=true
cmk -p admin create serviceoffering name="acs.comp.mem.large"   displaytext="Memory Optimized Large"    cpunumber=4  cpuspeed=2500 memory=8192  networkrate=500 offerha=true  dynamicscalingenabled=true limitcpuuse=true isvolatile=false deploymentplanner="UserDispersingPlanner" ispublic=true storagetype="shared" provisioningtype="thin" diskofferingstrictness=false rootdisksize=100 encryptroot=false purgeresources=true
cmk -p admin create serviceoffering name="acs.comp.mem.xlarge"  displaytext="Memory Optimized xLarge"   cpunumber=8  cpuspeed=2500 memory=16384 networkrate=500 offerha=true  dynamicscalingenabled=true limitcpuuse=true isvolatile=false deploymentplanner="UserDispersingPlanner" ispublic=true storagetype="shared" provisioningtype="thin" diskofferingstrictness=false rootdisksize=100 encryptroot=false purgeresources=true
cmk -p admin create serviceoffering name="acs.comp.mem.2xlarge" displaytext="Memory Optimized 2xLarge"  cpunumber=16 cpuspeed=2500 memory=32768 networkrate=500 offerha=true  dynamicscalingenabled=true limitcpuuse=true isvolatile=false deploymentplanner="UserDispersingPlanner" ispublic=true storagetype="shared" provisioningtype="thin" diskofferingstrictness=false rootdisksize=100 encryptroot=false purgeresources=true
cmk -p admin create serviceoffering name="acs.comp.ssd.small"   displaytext="Storage Optimized Small"   cpunumber=1  cpuspeed=2500 memory=1024  networkrate=200 offerha=false dynamicscalingenabled=true limitcpuuse=true isvolatile=false deploymentplanner="UserDispersingPlanner" ispublic=true storagetype="local"  provisioningtype="thin" diskofferingstrictness=false rootdisksize=30  encryptroot=false purgeresources=true
cmk -p admin create serviceoffering name="acs.comp.ssd.medium"  displaytext="Storage Optimized Medium"  cpunumber=2  cpuspeed=2500 memory=2048  networkrate=300 offerha=false dynamicscalingenabled=true limitcpuuse=true isvolatile=false deploymentplanner="UserDispersingPlanner" ispublic=true storagetype="local"  provisioningtype="thin" diskofferingstrictness=false rootdisksize=50  encryptroot=false purgeresources=true
cmk -p admin create serviceoffering name="acs.comp.ssd.large"   displaytext="Storage Optimized Large"   cpunumber=4  cpuspeed=2500 memory=4096  networkrate=500 offerha=false dynamicscalingenabled=true limitcpuuse=true isvolatile=false deploymentplanner="UserDispersingPlanner" ispublic=true storagetype="local"  provisioningtype="thin" diskofferingstrictness=false rootdisksize=100 encryptroot=false purgeresources=true
cmk -p admin create serviceoffering name="acs.comp.ssd.xlarge"  displaytext="Storage Optimized xLarge"  cpunumber=8  cpuspeed=2500 memory=8192  networkrate=500 offerha=false dynamicscalingenabled=true limitcpuuse=true isvolatile=false deploymentplanner="UserDispersingPlanner" ispublic=true storagetype="local"  provisioningtype="thin" diskofferingstrictness=false rootdisksize=100 encryptroot=false purgeresources=true
cmk -p admin create serviceoffering name="acs.comp.ssd.2xlarge" displaytext="Storage Optimized 2xLarge" cpunumber=16 cpuspeed=2500 memory=16384 networkrate=500 offerha=false dynamicscalingenabled=true limitcpuuse=true isvolatile=false deploymentplanner="UserDispersingPlanner" ispublic=true storagetype="local"  provisioningtype="thin" diskofferingstrictness=false rootdisksize=100 encryptroot=false purgeresources=true
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
cmk -p admin create networkoffering name="acs.net.shared.core-redundant"      displaytext="Shared Network with Redundant Virtual Router"                    guestiptype="Shared" traffictype="Guest" networkrate=500 specifyvlan=false conservemode=true egressdefaultpolicy=true ispublic=true enable=true specifyipranges=true ispersistent=false forvpc=false supportedservices="Vpn,Dhcp,Dns,Firewall,Lb,UserData,SourceNat,StaticNat,PortForwarding" "serviceproviderlist[0].service=Vpn" "serviceproviderlist[0].provider=VirtualRouter" "serviceproviderlist[1].service=Dhcp" "serviceproviderlist[1].provider=VirtualRouter" "serviceproviderlist[2].service=Dns" "serviceproviderlist[2].provider=VirtualRouter" "serviceproviderlist[3].service=Firewall" "serviceproviderlist[3].provider=VirtualRouter" "serviceproviderlist[4].service=Lb" "serviceproviderlist[4].provider=VirtualRouter" "serviceproviderlist[5].service=UserData" "serviceproviderlist[5].provider=VirtualRouter" "serviceproviderlist[6].service=SourceNat" "serviceproviderlist[6].provider=VirtualRouter" "serviceproviderlist[7].service=StaticNat" "serviceproviderlist[7].provider=VirtualRouter" "serviceproviderlist[8].service=PortForwarding" "serviceproviderlist[8].provider=VirtualRouter" "serviceCapabilityList[0].service=SourceNat" "serviceCapabilityList[0].capabilitytype=RedundantRouter" "serviceCapabilityList[0].capabilityvalue=true"
cmk -p admin create networkoffering name="acs.net.shared.core-redundant-vlan" displaytext="Shared Network with Redundant Virtual Router and VLAN specified" guestiptype="Shared" traffictype="Guest" networkrate=500 specifyvlan=true  conservemode=true egressdefaultpolicy=true ispublic=true enable=true specifyipranges=true ispersistent=false forvpc=false supportedservices="Vpn,Dhcp,Dns,Firewall,Lb,UserData,SourceNat,StaticNat,PortForwarding" "serviceproviderlist[0].service=Vpn" "serviceproviderlist[0].provider=VirtualRouter" "serviceproviderlist[1].service=Dhcp" "serviceproviderlist[1].provider=VirtualRouter" "serviceproviderlist[2].service=Dns" "serviceproviderlist[2].provider=VirtualRouter" "serviceproviderlist[3].service=Firewall" "serviceproviderlist[3].provider=VirtualRouter" "serviceproviderlist[4].service=Lb" "serviceproviderlist[4].provider=VirtualRouter" "serviceproviderlist[5].service=UserData" "serviceproviderlist[5].provider=VirtualRouter" "serviceproviderlist[6].service=SourceNat" "serviceproviderlist[6].provider=VirtualRouter" "serviceproviderlist[7].service=StaticNat" "serviceproviderlist[7].provider=VirtualRouter" "serviceproviderlist[8].service=PortForwarding" "serviceproviderlist[8].provider=VirtualRouter" "serviceCapabilityList[0].service=SourceNat" "serviceCapabilityList[0].capabilitytype=RedundantRouter" "serviceCapabilityList[0].capabilityvalue=true"


# Isolated Network offerings
cmk -p admin create networkoffering name="acs.net.isolated.core"           displaytext="Isolated Network with Virtual Router"           guestiptype="Isolated" traffictype="Guest" networkrate=500 specifyvlan=false ispersistent=true forvpc=false networkmode="NATTED" conservemode=true egressdefaultpolicy=true ispublic=true enable=true specifyipranges=false supportedservices="Vpn,Dhcp,Dns,Firewall,Lb,UserData,SourceNat,StaticNat,PortForwarding" "serviceproviderlist[0].service=Vpn" "serviceproviderlist[0].provider=VirtualRouter" "serviceproviderlist[1].service=Dhcp" "serviceproviderlist[1].provider=VirtualRouter" "serviceproviderlist[2].service=Dns" "serviceproviderlist[2].provider=VirtualRouter" "serviceproviderlist[3].service=Firewall" "serviceproviderlist[3].provider=VirtualRouter" "serviceproviderlist[4].service=Lb" "serviceproviderlist[4].provider=VirtualRouter" "serviceproviderlist[5].service=UserData" "serviceproviderlist[5].provider=VirtualRouter" "serviceproviderlist[6].service=SourceNat" "serviceproviderlist[6].provider=VirtualRouter" "serviceproviderlist[7].service=StaticNat" "serviceproviderlist[7].provider=VirtualRouter" "serviceproviderlist[8].service=PortForwarding" "serviceproviderlist[8].provider=VirtualRouter"
cmk -p admin create networkoffering name="acs.net.isolated.core-redundant" displaytext="Isolated Network with Redundant Virtual Router" guestiptype="Isolated" traffictype="Guest" networkrate=500 specifyvlan=false ispersistent=true forvpc=false networkmode="NATTED" conservemode=true egressdefaultpolicy=true ispublic=true enable=true specifyipranges=false supportedservices="Vpn,Dhcp,Dns,Firewall,Lb,UserData,SourceNat,StaticNat,PortForwarding" "serviceproviderlist[0].service=Vpn" "serviceproviderlist[0].provider=VirtualRouter" "serviceproviderlist[1].service=Dhcp" "serviceproviderlist[1].provider=VirtualRouter" "serviceproviderlist[2].service=Dns" "serviceproviderlist[2].provider=VirtualRouter" "serviceproviderlist[3].service=Firewall" "serviceproviderlist[3].provider=VirtualRouter" "serviceproviderlist[4].service=Lb" "serviceproviderlist[4].provider=VirtualRouter" "serviceproviderlist[5].service=UserData" "serviceproviderlist[5].provider=VirtualRouter" "serviceproviderlist[6].service=SourceNat" "serviceproviderlist[6].provider=VirtualRouter" "serviceproviderlist[7].service=StaticNat" "serviceproviderlist[7].provider=VirtualRouter" "serviceproviderlist[8].service=PortForwarding" "serviceproviderlist[8].provider=VirtualRouter" "serviceCapabilityList[0].service=SourceNat" "serviceCapabilityList[0].capabilitytype=RedundantRouter" "serviceCapabilityList[0].capabilityvalue=true"


# VPC Network offerings
cmk -p admin create networkoffering name="acs.net.vpc.core-internal-lb" displaytext="VPC Network with VpcVirtualRouter and Internal LB VM" guestiptype="Isolated" traffictype="Guest" networkrate=500 specifyvlan=false ispersistent=true forvpc=true networkmode="NATTED" conservemode=true egressdefaultpolicy=true ispublic=true enable=true specifyipranges=false internetprotocol="IPv4" guestiptype="Isolated" lbtype="internalLb" supportedservices="Vpn,Dhcp,Dns,Lb,UserData,SourceNat,StaticNat,PortForwarding,NetworkACL"                              "serviceproviderlist[0].service=Vpn" "serviceproviderlist[0].provider=VpcVirtualRouter" "serviceproviderlist[1].service=Dhcp" "serviceproviderlist[1].provider=VpcVirtualRouter" "serviceproviderlist[2].service=Dns" "serviceproviderlist[2].provider=VpcVirtualRouter" "serviceproviderlist[3].service=Lb" "serviceproviderlist[3].provider=InternalLbVm"     "serviceproviderlist[4].service=UserData" "serviceproviderlist[4].provider=VpcVirtualRouter" "serviceproviderlist[5].service=SourceNat" "serviceproviderlist[5].provider=VpcVirtualRouter" "serviceproviderlist[6].service=StaticNat" "serviceproviderlist[6].provider=VpcVirtualRouter" "serviceproviderlist[7].service=PortForwarding" "serviceproviderlist[7].provider=VpcVirtualRouter" "serviceproviderlist[8].service=NetworkACL" "serviceproviderlist[8].provider=VpcVirtualRouter" "serviceCapabilityList[0].service=SourceNat" "serviceCapabilityList[0].capabilitytype=SupportedSourceNatTypes" "serviceCapabilityList[0].capabilityvalue=peraccount" "serviceCapabilityList[1].service=lb" "serviceCapabilityList[1].capabilitytype=SupportedLbIsolation" "serviceCapabilityList[1].capabilityvalue=dedicated" "serviceCapabilityList[2].service=lb" "serviceCapabilityList[2].capabilitytype=lbSchemes"            "serviceCapabilityList[2].capabilityvalue=internal"
cmk -p admin create networkoffering name="acs.net.vpc.core-public-lb"   displaytext="VPC Network with VpcVirtualRouter and Public LB"      guestiptype="Isolated" traffictype="Guest" networkrate=500 specifyvlan=false ispersistent=true forvpc=true networkmode="NATTED" conservemode=true egressdefaultpolicy=true ispublic=true enable=true specifyipranges=false internetprotocol="IPv4" guestiptype="Isolated" lbtype="publicLb" vmautoscalingcapability="true" supportedservices="Vpn,Dhcp,Dns,Lb,UserData,SourceNat,StaticNat,PortForwarding,NetworkACL" "serviceproviderlist[0].service=Vpn" "serviceproviderlist[0].provider=VpcVirtualRouter" "serviceproviderlist[1].service=Dhcp" "serviceproviderlist[1].provider=VpcVirtualRouter" "serviceproviderlist[2].service=Dns" "serviceproviderlist[2].provider=VpcVirtualRouter" "serviceproviderlist[3].service=Lb" "serviceproviderlist[3].provider=VpcVirtualRouter" "serviceproviderlist[4].service=UserData" "serviceproviderlist[4].provider=VpcVirtualRouter" "serviceproviderlist[5].service=SourceNat" "serviceproviderlist[5].provider=VpcVirtualRouter" "serviceproviderlist[6].service=StaticNat" "serviceproviderlist[6].provider=VpcVirtualRouter" "serviceproviderlist[7].service=PortForwarding" "serviceproviderlist[7].provider=VpcVirtualRouter" "serviceproviderlist[8].service=NetworkACL" "serviceproviderlist[8].provider=VpcVirtualRouter" "serviceCapabilityList[0].service=SourceNat" "serviceCapabilityList[0].capabilitytype=SupportedSourceNatTypes" "serviceCapabilityList[0].capabilityvalue=peraccount" "serviceCapabilityList[1].service=lb" "serviceCapabilityList[1].capabilitytype=VmAutoScaling"        "serviceCapabilityList[1].capabilityvalue=true"      "serviceCapabilityList[2].service=lb" "serviceCapabilityList[2].capabilitytype=SupportedLbIsolation" "serviceCapabilityList[2].capabilityvalue=dedicated"
```

### VPC Offering

```bash
cmk -p admin create vpcoffering name="acs.vpc.natted.core"           displaytext="NATTED Single Virtual Router VPC with VpcVirtualRouter, ConfigDrive, InternalLbVm"    internetprotocol="IPv4" ispublic=true enable=true networkmode="NATTED" supportedservices="Vpn,Dhcp,Dns,Lb,Gateway,UserData,SourceNat,StaticNat,PortForwarding,NetworkACL" "serviceproviderlist[0].service=Vpn" "serviceproviderlist[0].provider=VpcVirtualRouter" "serviceproviderlist[1].service=Dhcp" "serviceproviderlist[1].provider=VpcVirtualRouter" "serviceproviderlist[2].service=Dhcp" "serviceproviderlist[2].provider=ConfigDrive" "serviceproviderlist[3].service=Dns" "serviceproviderlist[3].provider=VpcVirtualRouter" "serviceproviderlist[4].service=Dns" "serviceproviderlist[4].provider=ConfigDrive" "serviceproviderlist[5].service=Lb" "serviceproviderlist[5].provider=InternalLbVm" "serviceproviderlist[6].service=Lb" "serviceproviderlist[6].provider=VpcVirtualRouter" "serviceproviderlist[7].service=Gateway" "serviceproviderlist[7].provider=VpcVirtualRouter" "serviceproviderlist[8].service=UserData" "serviceproviderlist[8].provider=VpcVirtualRouter" "serviceproviderlist[9].service=UserData" "serviceproviderlist[9].provider=ConfigDrive" "serviceproviderlist[10].service=SourceNat" "serviceproviderlist[10].provider=VpcVirtualRouter" "serviceproviderlist[11].service=StaticNat" "serviceproviderlist[11].provider=VpcVirtualRouter" "serviceproviderlist[12].service=PortForwarding" "serviceproviderlist[12].provider=VpcVirtualRouter" "serviceproviderlist[13].service=NetworkACL" "serviceproviderlist[13].provider=VpcVirtualRouter"
cmk -p admin create vpcoffering name="acs.vpc.natted.redundant-core" displaytext="NATTED Redundant Virtual Router VPC with VpcVirtualRouter, ConfigDrive, InternalLbVm" internetprotocol="IPv4" ispublic=true enable=true networkmode="NATTED" supportedservices="Vpn,Dhcp,Dns,Lb,Gateway,UserData,SourceNat,StaticNat,PortForwarding,NetworkACL" "serviceproviderlist[0].service=Vpn" "serviceproviderlist[0].provider=VpcVirtualRouter" "serviceproviderlist[1].service=Dhcp" "serviceproviderlist[1].provider=VpcVirtualRouter" "serviceproviderlist[2].service=Dhcp" "serviceproviderlist[2].provider=ConfigDrive" "serviceproviderlist[3].service=Dns" "serviceproviderlist[3].provider=VpcVirtualRouter" "serviceproviderlist[4].service=Dns" "serviceproviderlist[4].provider=ConfigDrive" "serviceproviderlist[5].service=Lb" "serviceproviderlist[5].provider=InternalLbVm" "serviceproviderlist[6].service=Lb" "serviceproviderlist[6].provider=VpcVirtualRouter" "serviceproviderlist[7].service=Gateway" "serviceproviderlist[7].provider=VpcVirtualRouter" "serviceproviderlist[8].service=UserData" "serviceproviderlist[8].provider=VpcVirtualRouter" "serviceproviderlist[9].service=UserData" "serviceproviderlist[9].provider=ConfigDrive" "serviceproviderlist[10].service=SourceNat" "serviceproviderlist[10].provider=VpcVirtualRouter" "serviceproviderlist[11].service=StaticNat" "serviceproviderlist[11].provider=VpcVirtualRouter" "serviceproviderlist[12].service=PortForwarding" "serviceproviderlist[12].provider=VpcVirtualRouter" "serviceproviderlist[13].service=NetworkACL" "serviceproviderlist[13].provider=VpcVirtualRouter" "serviceCapabilityList[0].service=SourceNat" "serviceCapabilityList[0].capabilitytype=RedundantRouter" "serviceCapabilityList[0].capabilityvalue=true"
```

## Templates

```bash
# Variables - Customize these for your environment
ZONE_NAME="zone-homecloud"
ZONE_ID=$(cmk -p admin list zones name="$ZONE_NAME" | jq -r '.zone[0].id')

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
  "details[0].guest.cpu.mode=host-mode" \
  "details[0].nicAdapter=rtl8139" \
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
  "details[0].guest.cpu.mode=host-mode" \
  "details[0].nicAdapter=rtl8139" \
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

# Windows Server 2025 ISO (https://www.microsoft.com/en-us/evalcenter/download-windows-server-2025)
echo "Registering Windows Server 2025 ISO..."
cmk -p admin register iso \
  displaytext="Windows Server 2025 ISO" \
  name="windows-server-2025" \
  url="https://software-static.download.prss.microsoft.com/dbazure/888969d5-f34g-4e03-ac9d-1f9786c66749/26100.1742.240906-0331.ge_release_svc_refresh_SERVER_EVAL_x64FRE_en-us.iso" \
  zoneid="$ZONE_ID" \
  bootable=true \
  ispublic=true \
  isfeatured=true \
  ostypeid=$(cmk -p admin list ostypes description="Windows Server 2025" | jq -r '.ostype[0].id')

# VirtIO Drivers for Windows
echo "Registering VirtIO drivers ISO for Windows..."
cmk -p admin register iso \
  displaytext="VirtIO drivers for Windows VMs" \
  name="virtio-win" \
  url="https://fedorapeople.org/groups/virt/virtio-win/direct-downloads/stable-virtio/virtio-win.iso" \
  zoneid="$ZONE_ID" \
  bootable=false \
  ispublic=true \
  isfeatured=false \
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
  userdata="$(cat cloudstack/compute/cloud-init/cloud-default.yaml | base64)" \
  account=homecloud \
  domainid="$HOMECLOUD_DOMAIN_ID"

# tailscale-router-debian user data
echo "Registering tailscale-router-debian user data..."
cmk -p homecloud-admin registerUserData \
  name="tailscale-router-debian" \
  userdata="$(cat cloudstack/compute/cloud-init/tailscale-router-debian.yaml | base64)" \
  account=homecloud \
  domainid="$HOMECLOUD_DOMAIN_ID" \
  "params=tailscale_auth_key,network_router_cidr"

echo "Registering CNI Configurations..."

# Cilium CNI configuration
echo "Registering Cilium CNI configuration..."
cmk -p homecloud-admin registerCniConfiguration \
  name="cilium" \
  description="Cilium CNI configuration for CKS clusters" \
  cniconfig="$(tail -n +3 cloudstack/compute/cni-config/cilium.yaml | base64)" \
  account=homecloud \
  domainid="$HOMECLOUD_DOMAIN_ID" \
  params="cilium_version"

# SSH Key Pair
cmk -p homecloud-admin register sshkeypair \
  name="nulcell" \
  publickey="$(op read "op://homecloud/nulcell/public key")" \
  account=homecloud \
  domainid="$HOMECLOUD_DOMAIN_ID"
```

## VPC

```bash
ACCOUNT_NAME="homecloud"
ZONE_NAME="zone-homecloud"
ZONE_ID=$(cmk -p admin list zones name="$ZONE_NAME" | jq -r '.zone[0].id')
HOMECLOUD_DOMAIN_ID=$(cmk -p homecloud-admin list domains name=homecloud | jq -r '.domain[0].id')
```

### Dev VPC

```bash
DEV_VPC_NAME="hc-vpc-dev"
DEV_VPC_CIDR="10.0.0.0/24"

VPC_OFFERING_ID=$(cmk -p homecloud-admin list vpcofferings name="acs.vpc.natted.redundant-core" | jq -r '.vpcoffering[0].id')
PUBLIC_LB_OFFERING_ID=$(cmk -p homecloud-admin list networkofferings name="acs.net.vpc.core-public-lb" | jq -r '.networkoffering[0].id')
INTERNAL_LB_OFFERING_ID=$(cmk -p homecloud-admin list networkofferings name="acs.net.vpc.core-internal-lb" | jq -r '.networkoffering[0].id')

DEV_VPC_ID=$(cmk -p homecloud-admin create vpc \
  name="$DEV_VPC_NAME" \
  displaytext="Homecloud VPC Development Network" \
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
PROD_VPC_NAME="hc-vpc-prod"
PROD_VPC_CIDR="10.1.1.0/24"

VPC_OFFERING_ID=$(cmk -p homecloud-admin list vpcofferings name="acs.vpc.natted.redundant-core" | jq -r '.vpcoffering[0].id')
PUBLIC_LB_OFFERING_ID=$(cmk -p homecloud-admin list networkofferings name="acs.net.vpc.core-public-lb" | jq -r '.networkoffering[0].id')
INTERNAL_LB_OFFERING_ID=$(cmk -p homecloud-admin list networkofferings name="acs.net.vpc.core-internal-lb" | jq -r '.networkoffering[0].id')

PROD_VPC_ID=$(cmk -p homecloud-admin create vpc \
  name="$PROD_VPC_NAME" \
  displaytext="Homecloud VPC Production Network" \
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
ACCOUNT_NAME="homecloud"
ZONE_NAME="zone-homecloud"
ZONE_ID=$(cmk -p admin list zones name="$ZONE_NAME" | jq -r '.zone[0].id')
HOMECLOUD_DOMAIN_ID=$(cmk -p homecloud-admin list domains name=homecloud | jq -r '.domain[0].id')

ISOLATED_NETWORK_NAME="iso-net-shared"
ISOLATED_NETWORK_CIDR="10.2.2.0/24"

ISOLATED_OFFERING_ID=$(cmk -p homecloud-admin list networkofferings name="acs.net.isolated.core-redundant" | jq -r '.networkoffering[0].id')

ISOLATED_NETWORK_ID=$(cmk -p homecloud-admin create network \
  name="$ISOLATED_NETWORK_NAME" \
  displaytext="Homecloud Shared Isolated Network" \
  networkofferingid="$ISOLATED_OFFERING_ID" \
  zoneid="$ZONE_ID" \
  gateway="10.2.2.1" \
  netmask="255.255.255.0" \
  account="$ACCOUNT_NAME" \
  domainid="$HOMECLOUD_DOMAIN_ID" \
  | jq -r '.network.id')
```

## VPN

```bash
ACCOUNT_NAME="homecloud"
ZONE_NAME="zone-homecloud"
ZONE_ID=$(cmk -p admin list zones name="$ZONE_NAME" | jq -r '.zone[0].id')
HOMECLOUD_DOMAIN_ID=$(cmk -p homecloud-admin list domains name=homecloud | jq -r '.domain[0].id')
TAILSCALE_USERDATA_ID=$(cmk -p homecloud-admin list userdata name="tailscale-router-debian" account="$ACCOUNT_NAME" domainid="$HOMECLOUD_DOMAIN_ID" | jq -r '.userdata[0].id')
UBUNTU_TEMPLATE_ID=$(cmk -p homecloud-admin list templates templatefilter=all name="Ubuntu 24.04 - Noble" zoneid="$ZONE_ID" | jq -r '.template[0].id')
COMPUTE_OFFERING_ID=$(cmk -p homecloud-admin list serviceofferings name="acs.comp.gen.tiny" | jq -r '.serviceoffering[0].id')

TAILSCALE_AUTH_KEY=$(op read "op://homecloud/Tailscale Token/credential")
```

### Dev VPN

```bash
DEV_VPC_CIDR="10.0.0.0/24"
DEV_PUB_NET_1_ID=$(cmk -p homecloud-admin list networks name="hc-vpc-dev_pub-net-1" account="homecloud" domainid="$HOMECLOUD_DOMAIN_ID" | jq -r '.network[0].id')
DEV_PRIV_NET_1_ID=$(cmk -p homecloud-admin list networks name="hc-vpc-dev_priv-net-1" account="homecloud" domainid="$HOMECLOUD_DOMAIN_ID" | jq -r '.network[0].id')
DEV_PRIV_NET_2_ID=$(cmk -p homecloud-admin list networks name="hc-vpc-dev_priv-net-2" account="homecloud" domainid="$HOMECLOUD_DOMAIN_ID" | jq -r '.network[0].id')
DEV_PRIV_NET_3_ID=$(cmk -p homecloud-admin list networks name="hc-vpc-dev_priv-net-3" account="homecloud" domainid="$HOMECLOUD_DOMAIN_ID" | jq -r '.network[0].id')

DEV_ROUTER_VM_ID=$(cmk -p homecloud-admin deploy virtualmachine \
  name="hc-vpn-router-dev" \
  displayname="hc-vpn-router-dev" \
  serviceofferingid="$COMPUTE_OFFERING_ID" \
  templateid="$UBUNTU_TEMPLATE_ID" \
  zoneid="$ZONE_ID" \
  networkids="$DEV_PUB_NET_1_ID,$DEV_PRIV_NET_1_ID,$DEV_PRIV_NET_2_ID,$DEV_PRIV_NET_3_ID" \
  account="$ACCOUNT_NAME" \
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
PROD_PUB_NET_1_ID=$(cmk -p homecloud-admin list networks name="hc-vpc-prod_pub-net-1" account="homecloud" domainid="$HOMECLOUD_DOMAIN_ID" | jq -r '.network[0].id')
PROD_PRIV_NET_1_ID=$(cmk -p homecloud-admin list networks name="hc-vpc-prod_priv-net-1" account="homecloud" domainid="$HOMECLOUD_DOMAIN_ID" | jq -r '.network[0].id')
PROD_PRIV_NET_2_ID=$(cmk -p homecloud-admin list networks name="hc-vpc-prod_priv-net-2" account="homecloud" domainid="$HOMECLOUD_DOMAIN_ID" | jq -r '.network[0].id')
PROD_PRIV_NET_3_ID=$(cmk -p homecloud-admin list networks name="hc-vpc-prod_priv-net-3" account="homecloud" domainid="$HOMECLOUD_DOMAIN_ID" | jq -r '.network[0].id')

PROD_ROUTER_VM_ID=$(cmk -p homecloud-admin deploy virtualmachine \
  name="hc-vpn-router-prod" \
  displayname="hc-vpn-router-prod" \
  serviceofferingid="$COMPUTE_OFFERING_ID" \
  templateid="$UBUNTU_TEMPLATE_ID" \
  zoneid="$ZONE_ID" \
  networkids="$PROD_PUB_NET_1_ID,$PROD_PRIV_NET_1_ID,$PROD_PRIV_NET_2_ID,$PROD_PRIV_NET_3_ID" \
  account="$ACCOUNT_NAME" \
  domainid="$HOMECLOUD_DOMAIN_ID" \
  userdataid="$TAILSCALE_USERDATA_ID" \
  "userdatadetails[0].tailscale_auth_key=$TAILSCALE_AUTH_KEY" \
  "userdatadetails[0].network_router_cidr=$PROD_VPC_CIDR" \
  keypair="nulcell" \
  | jq -r '.virtualmachine.id')
```

## VPS

```bash
ACCOUNT_NAME="homecloud"
ZONE_NAME="zone-homecloud"
ZONE_ID=$(cmk -p admin list zones name="$ZONE_NAME" | jq -r '.zone[0].id')
HOMECLOUD_DOMAIN_ID=$(cmk -p homecloud-admin list domains name=homecloud | jq -r '.domain[0].id')
DEFAULT_USERDATA_ID=$(cmk -p homecloud-admin list userdata name="cloud-default" account="$ACCOUNT_NAME" domainid="$HOMECLOUD_DOMAIN_ID" | jq -r '.userdata[0].id')
UBUNTU_TEMPLATE_ID=$(cmk -p homecloud-admin list templates templatefilter=all name="Ubuntu 24.04 - Noble" zoneid="$ZONE_ID" | jq -r '.template[0].id')
```

### Dev VPS

```bash
DEV_COMPUTE_OFFERING_ID=$(cmk -p homecloud-admin list serviceofferings name="acs.comp.gen.large" | jq -r '.serviceoffering[0].id')
DEV_VPS_NETWORK_ID=$(cmk -p homecloud-admin list networks name="hc-vpc-dev_priv-net-2" account="homecloud" domainid="$HOMECLOUD_DOMAIN_ID" | jq -r '.network[0].id')

DEV_VPS_ID=$(cmk -p homecloud-admin deploy virtualmachine \
  name="hc-vps-dev" \
  displayname="hc-vps-dev" \
  serviceofferingid="$DEV_COMPUTE_OFFERING_ID" \
  templateid="$UBUNTU_TEMPLATE_ID" \
  zoneid="$ZONE_ID" \
  networkids="$DEV_VPS_NETWORK_ID" \
  userdataid="$DEFAULT_USERDATA_ID" \
  account="$ACCOUNT_NAME" \
  domainid="$HOMECLOUD_DOMAIN_ID" \
  keypair="nulcell" \
  | jq -r '.virtualmachine.id')
```

### Prod VPS

```bash
PROD_COMPUTE_OFFERING_ID=$(cmk -p homecloud-admin list serviceofferings name="acs.comp.gen.xlarge" | jq -r '.serviceoffering[0].id')
PROD_VPS_NETWORK_ID=$(cmk -p homecloud-admin list networks name="hc-vpc-prod_priv-net-2" account="homecloud" domainid="$HOMECLOUD_DOMAIN_ID" | jq -r '.network[0].id')

PROD_VPS_ID=$(cmk -p homecloud-admin deploy virtualmachine \
  name="hc-vps-prod" \
  displayname="hc-vps-prod" \
  serviceofferingid="$PROD_COMPUTE_OFFERING_ID" \
  templateid="$UBUNTU_TEMPLATE_ID" \
  zoneid="$ZONE_ID" \
  networkids="$PROD_VPS_NETWORK_ID" \
  userdataid="$DEFAULT_USERDATA_ID" \
  account="$ACCOUNT_NAME" \
  domainid="$HOMECLOUD_DOMAIN_ID" \
  keypair="nulcell" \
  | jq -r '.virtualmachine.id')
```

## Kubernetes Cluster

**Note:** If cluster creation fails, check that the account has sufficient resource limits for CPU, RAM, and primary storage.

```bash
ACCOUNT_NAME="homecloud"
ZONE_NAME="zone-homecloud"
ZONE_ID=$(cmk -p admin list zones name="$ZONE_NAME" | jq -r '.zone[0].id')
HOMECLOUD_DOMAIN_ID=$(cmk -p homecloud-admin list domains name=homecloud | jq -r '.domain[0].id')
CKS_OFFERING_ID=$(cmk -p homecloud-admin list kubernetessupportedversions keyword="cks-v1.34.2-cilium_v1.18.2-x86_64" zoneid="$ZONE_ID" | jq -r '.kubernetessupportedversion[0].id')
CNI_CONFIG_ID=$(cmk -p homecloud-admin listCniConfiguration name="cilium" account="$ACCOUNT_NAME" domainid="$HOMECLOUD_DOMAIN_ID" | jq -r '.cniconfig[0].id')
```

### Dev CKS Cluster

```bash
echo "Creating Development CKS Cluster (this takes 15-30 minutes)..."
DEV_PUB_NET_1_ID=$(cmk -p homecloud-admin list networks name="hc-vpc-dev_pub-net-1" account="homecloud" domainid="$HOMECLOUD_DOMAIN_ID" | jq -r '.network[0].id')
CKS_SERVICE_OFFERING_ID_CONTROL=$(cmk -p homecloud-admin list serviceofferings name="acs.comp.gen.large" | jq -r '.serviceoffering[0].id')
CKS_SERVICE_OFFERING_ID_WORKER=$(cmk -p homecloud-admin list serviceofferings name="acs.comp.gen.large" | jq -r '.serviceoffering[0].id')
CKS_SERVICE_OFFERING_ID=$CKS_SERVICE_OFFERING_ID_WORKER
DEV_CKS_ID=$(cmk -p homecloud-admin create kubernetescluster \
  name="hc-cks-dev" \
  description="Homecloud Development Kubernetes Cluster" \
  zoneid="$ZONE_ID" \
  kubernetesversionid="$CKS_OFFERING_ID" \
  serviceofferingid="$CKS_SERVICE_OFFERING_ID" \
  "nodeofferings[0].node=control" \
  "nodeofferings[0].offering=$CKS_SERVICE_OFFERING_ID_CONTROL" \
  "nodeofferings[1].node=worker" \
  "nodeofferings[1].offering=$CKS_SERVICE_OFFERING_ID_WORKER" \
  noderootdisksize=50 \
  networkid="$DEV_PUB_NET_1_ID" \
  account="$ACCOUNT_NAME" \
  domainid="$HOMECLOUD_DOMAIN_ID" \
  hypervisor="KVM" \
  controlnodes=1 \
  size=1 \
  keypair="nulcell" \
  enablecsi=true \
  cniconfigurationid="$CNI_CONFIG_ID" \
  "cniconfigdetails[0].cilium_version=1.18.4" \
  | jq -r '.kubernetescluster.id')
cmk -p homecloud-admin scaleKubernetesCluster id="$DEV_CKS_ID" \
  autoscalingenabled=true \
  minsize=1 \
  maxsize=3 \
  "nodeofferings[0].node=control" \
  "nodeofferings[0].offering=$CKS_SERVICE_OFFERING_ID_CONTROL" \
  "nodeofferings[1].node=worker" \
  "nodeofferings[1].offering=$CKS_SERVICE_OFFERING_ID_WORKER"

echo "Retrieving kubeconfig for Development CKS Cluster..."
cmk -p homecloud-admin getKubernetesClusterConfig id="$DEV_CKS_ID" | jq -r .clusterconfig.configdata > dev-cks-kubeconfig.yaml
sed -i '' 's/kubernetes-admin@kubernetes/admin@hc-cks-dev/g' dev-cks-kubeconfig.yaml
sed -i '' 's/kubernetes-admin/hc-cks-dev-admin/g' dev-cks-kubeconfig.yaml
sed -i '' 's/kubernetes/hc-cks-dev/g' dev-cks-kubeconfig.yaml
kubectl config delete-context admin@hc-cks-dev || true
kubectl config delete-user hc-cks-dev-admin || true
kubectl config delete-cluster hc-cks-dev || true
kubectl konfig import -s dev-cks-kubeconfig.yaml
rm dev-cks-kubeconfig.yaml
echo "Development CKS Cluster ID: $DEV_CKS_ID"
```

### Prod CKS Cluster

```bash
echo "Creating Production CKS Cluster (this takes 15-30 minutes)..."
PROD_PUB_NET_1_ID=$(cmk -p homecloud-admin list networks name="hc-vpc-prod_pub-net-1" account="homecloud" domainid="$HOMECLOUD_DOMAIN_ID" | jq -r '.network[0].id')
CKS_SERVICE_OFFERING_ID_CONTROL=$(cmk -p homecloud-admin list serviceofferings name="acs.comp.gen.large" | jq -r '.serviceoffering[0].id')
CKS_SERVICE_OFFERING_ID_WORKER=$(cmk -p homecloud-admin list serviceofferings name="acs.comp.mem.large" | jq -r '.serviceoffering[0].id')
CKS_SERVICE_OFFERING_ID=$CKS_SERVICE_OFFERING_ID_WORKER
PROD_CKS_ID=$(cmk -p homecloud-admin create kubernetescluster \
  name="hc-cks-prod" \
  description="Homecloud Production Kubernetes Cluster" \
  zoneid="$ZONE_ID" \
  kubernetesversionid="$CKS_OFFERING_ID" \
  serviceofferingid="$CKS_SERVICE_OFFERING_ID" \
  "nodeofferings[0].node=control" \
  "nodeofferings[0].offering=$CKS_SERVICE_OFFERING_ID_CONTROL" \
  "nodeofferings[1].node=worker" \
  "nodeofferings[1].offering=$CKS_SERVICE_OFFERING_ID_WORKER" \
  noderootdisksize=50 \
  networkid="$PROD_PUB_NET_1_ID" \
  account="$ACCOUNT_NAME" \
  domainid="$HOMECLOUD_DOMAIN_ID" \
  hypervisor="KVM" \
  controlnodes=1 \
  size=2 \
  keypair="nulcell" \
  enablecsi=true \
  cniconfigurationid="$CNI_CONFIG_ID" \
  "cniconfigdetails[0].cilium_version=1.18.4" \
  | jq -r '.kubernetescluster.id')
cmk -p homecloud-admin scaleKubernetesCluster id="$PROD_CKS_ID" \
  autoscalingenabled=true \
  minsize=1 \
  maxsize=5 \
  "nodeofferings[0].node=control" \
  "nodeofferings[0].offering=$CKS_SERVICE_OFFERING_ID_CONTROL" \
  "nodeofferings[1].node=worker" \
  "nodeofferings[1].offering=$CKS_SERVICE_OFFERING_ID_WORKER"

echo "Retrieving kubeconfig for Production CKS Cluster..."
cmk -p homecloud-admin getKubernetesClusterConfig id="$PROD_CKS_ID" | jq -r .clusterconfig.configdata > prod-cks-kubeconfig.yaml
sed -i '' 's/kubernetes-admin@kubernetes/admin@hc-cks-prod/g' prod-cks-kubeconfig.yaml
sed -i '' 's/kubernetes-admin/hc-cks-prod-admin/g' prod-cks-kubeconfig.yaml
sed -i '' 's/kubernetes/hc-cks-prod/g' prod-cks-kubeconfig.yaml
kubectl config delete-context admin@hc-cks-prod || true
kubectl config delete-user hc-cks-prod-admin || true
kubectl config delete-cluster hc-cks-prod || true
kubectl konfig import -s prod-cks-kubeconfig.yaml
rm prod-cks-kubeconfig.yaml
echo "Production CKS Cluster ID: $PROD_CKS_ID"
```
