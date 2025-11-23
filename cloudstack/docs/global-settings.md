# Global Configurations

## Access

### Domain

- **metadata.allow.expose.domain**:
  - Description: If set to true, it allows the VM's domain to be seen in metadata.
  - Value: true

## Compute

### VM

- **enable.additional.vm.configuration**:
  - Description: Allow additional arbitrary configuration to vm
  - Value: true
- **enable.dynamic.scale.vm**:
  - Description: Enables/Disables dynamically scaling a VM.
  - Value: false (default but you can enable it as needed)
- **instance.lease.enabled**:
  - Description: Indicates whether to enable the Instance lease, will be applicable only on instances created after lease is enabled. Disabling the feature cancels lease on existing instances with lease. Re-enabling feature will not cause lease expiry actions on grandfathered instances.
  - Value: true
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

### Kubernetes

- **cloud.kubernetes.cluster.experimental.features.enabled**:
  - Description: Enable experimental features for Kubernetes clusters.
  - Value: true

## Storage

### Volume

- **destroy.root.volume.on.vm.destruction**:
  - Description: Destroys the VM's root volume when the VM is destroyed.
  - Value: true

### Snapshot

- **snapshot.delta.max**:
  - Description: Max delta snapshots between two full snapshots. Only valid for KVM and XenServer.
  - Value: 32

## Network

### Network

- **network.throttling.rate**:
  - Description: Default data transfer rate in megabits per second allowed in network.
  - Value: 500

### VPC

- **vpc.max.networks**:
  - Description: Maximum number of networks per vpc.
  - Value: 8
- **vpc.tier.name.prepend**:
  - Description: Whether to prepend the VPC name to the VPC tier network name.
  - Value: true
- **vpc.tier.name.prepend.delimiter**:
  - Description: Delimiter string to use between the VPC and the VPC tier name.
  - Value: `_`

## Hypervisor

### KVM

- **enable.kvm.host.auto.enable.disable**:
  - Description: (KVM only) Enable Auto Disable/Enable KVM hosts in the cluster according to the hosts health check results.
  - Value: true
- **kvm.incremental.snapshot**:
  - Description: Whether differential snapshots are enabled for KVM or not. When this is enabled, all KVM snapshots will be incremental. Bear in mind that it will generate a new full snapshot when the snapshot chain reaches the limit defined in snapshot.delta.max.
  - Value: true

## Management Server

### API

- **enable.ec2.api**:
  - Description: enable EC2 API on CloudStack.
  - Value: true
- **enable.s3.api**:
  - Description: enable Amazon S3 API on CloudStack.
  - Value: true

## System VMs

### Console Proxy VM

- **consoleproxy.sslEnabled**:
  - Description: Enable SSL for console proxy.
  - Value: true

## Miscellaneous

### Others

- **endpoint.url**:
  - Description: The endpoint URL for the management server.
  - Value: `http://10.10.16.60:8080/client/api`  # Set to the management server or load balancer URL (it should be publicly resolvable if it a hostname and not an IP)
- **store.download.follow.redirects**:
  - Description: Whether HTTP redirect is followed during store downloads for objects such as template, volume etc.
  - Value: true
