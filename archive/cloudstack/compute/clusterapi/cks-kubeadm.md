# CloudStack Cluster API (CKS + Kubeadm)

This directory contains the procedures and configurations necessary to set up a number of CloudStack kubernetes clusters using the Cluster API (CAPI) framework. Ensure that [clusterctl](https://cluster-api.sigs.k8s.io/user/quick-start.html#install-clusterctl) is installed on your local machine.

## Managing Cluster API Image Templates

Register templates with the following format for names - `capi-v<k8s-version>-<os>-<hypervisor>`. For example, for Kubernetes version 1.32.3 with Ubuntu 22.04, the template name would be `capi-v1.32.3-ubuntu-2204-kvm`.

### Pre-built Image Templates

Pre-built images from ShapeBlue can be downloaded from the [ShapeBlue Package Repository](http://packages.shapeblue.com/cluster-api-provider-cloudstack/images/kvm/)

### Building Custom Image Templates

Follow the instructions in the [Cluster API Provider CloudStack documentation](https://image-builder.sigs.k8s.io/capi/providers/cloudstack.html) to build custom image templates for your CloudStack environment and upload the images to S3 to them pull them during template creation.

## Cluster API Management Cluster Setup with CKS

Utilise the Operations CKS cluster created during the [CloudStack CKS Setup](./00-CLI.md) to run Cluster API commands.

### Setup CloudStack Credentials Secret

Create a secret in the management cluster with your CloudStack API credentials:

```sh
kubectl apply -f - <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: cloudstack-credentials
  namespace: default
type: Opaque
stringData:
  api-key: $(op read "op://homecloud/3e3bkhqdxb7xlynn3cu6lf3az4/API/api-key")
  secret-key: $(op read "op://homecloud/3e3bkhqdxb7xlynn3cu6lf3az4/API/secret-key")
  api-url: $(op read "op://homecloud/3e3bkhqdxb7xlynn3cu6lf3az4/API/api-url")
  verify-ssl: "false"
EOF
```

### Initialize the management cluster

```sh
CAPC_CLOUDSTACKMACHINE_CKS_SYNC=true clusterctl init --infrastructure cloudstack
```

## Creating Workload Clusters

Create workload clusters using the management cluster created above

```sh
# The Apache CloudStack zone in which the cluster is to be deployed
export CLOUDSTACK_ZONE_NAME=zone-homecloud

# If the referenced network doesn't exist, a new isolated network
# will be created.
export CLOUDSTACK_NETWORK_NAME=homecloud-vpc_pub-net-1

# The IP you put here must be available as an unused public IP on the network
# referenced above. If it's not available, the control plane will fail to create.
# You can see the list of available IP's when you try allocating a public
# IP in the network at
# Network -> Guest Networks -> <Network Name> -> IP Addresses
export CLUSTER_ENDPOINT_IP=10.10.20.40

# This is the standard port that the Control Plane process runs on
export CLUSTER_ENDPOINT_PORT=6443

# Machine offerings must be pre-created. Control plane offering
# must have have >2GB RAM available
export CLOUDSTACK_CONTROL_PLANE_MACHINE_OFFERING="mem.medium.fixed"
export CLOUDSTACK_WORKER_MACHINE_OFFERING="gen.1xlarge.fixed"

# Referring to a prerequisite capi-compatible image you've loaded into Apache CloudStack
export CLOUDSTACK_TEMPLATE_NAME=capi-v1.32.3-ubuntu-2204-kvm

# The SSH KeyPair to log into the VM (Optional: you must use clusterctl --flavor *managed-ssh*)
export CLOUDSTACK_SSH_KEY_NAME=nulcell

# Sync resources created by CAPC in Apache Cloudstack CKS. Default is false.
# Requires setting CAPC_CLOUDSTACKMACHINE_CKS_SYNC=true before initialising the cloudstack provider.
# Or set enable-cloudstack-cks-sync to true in the deployment for capc-controller.
export CLOUDSTACK_SYNC_WITH_ACS=true
```

### Cluster Creation

Create the cluster manifest if it doesn't already exist:

```sh
kubectl config use-context admin@homecloud-ops-cks
clusterctl generate cluster homecloud-cks \
    --kubernetes-version v1.32.3 \
    --flavor managed-ssh \
    --infrastructure cloudstack \
    --control-plane-machine-count=3 \
    --worker-machine-count=3 \
    > cloudstack/compute/clusterapi/homecloud-cks-cluster-spec.yaml
```

Modify `cloudstack/compute/clusterapi/homecloud-cks-cluster-spec.yaml` as needed to adjust the cluster configuration, such as changing the number of worker nodes, machine templates, etc.

```sh
kubectl apply -f cloudstack/compute/clusterapi/homecloud-cks-cluster-spec.yaml
clusterctl get kubeconfig homecloud-cks > cloudstack/compute/clusterapi/homecloud-cks.kubeconfig
kubectl config delete-context homecloud-cks-admin@homecloud-cks || true
kubectl config delete-user homecloud-cks-admin || true
kubectl config delete-cluster homecloud-cks || true
kubectl konfig import -s cloudstack/compute/clusterapi/homecloud-cks.kubeconfig
kubectl config use-context homecloud-cks-admin@homecloud-cks
rm cloudstack/compute/clusterapi/homecloud-cks.kubeconfig
```

### Post-deployment Processes

```sh
# Create secret for CloudStack Provider and CSI Driver
cat > cloudstack/compute/clusterapi/cloud-config <<EOF
[Global]
api-url = $(op read "op://homecloud/3e3bkhqdxb7xlynn3cu6lf3az4/API/api-url")
api-key = $(op read "op://homecloud/3e3bkhqdxb7xlynn3cu6lf3az4/API/api-key")
secret-key = $(op read "op://homecloud/3e3bkhqdxb7xlynn3cu6lf3az4/API/secret-key")
zone = $CLOUDSTACK_ZONE_NAME
ssl-no-verify = false
EOF
kubectl -n kube-system create secret generic cloudstack-secret --from-file=cloudstack/compute/clusterapi/cloud-config
rm cloudstack/compute/clusterapi/cloud-config

# Deploy CloudStack Provider and CSI Driver
kubectl apply -f https://github.com/apache/cloudstack-kubernetes-provider/releases/download/v1.1.0/deployment.yaml
kubectl apply -f https://github.com/cloudstack/cloudstack-csi-driver/releases/download/v3.0.0/snapshot-crds.yaml
wget https://github.com/cloudstack/cloudstack-csi-driver/releases/download/v3.0.0/manifest.yaml -O cloudstack/compute/clusterapi/cloudstack-csi-driver.yaml
# fix typo in the csi driver manifest from `rbac.authorization.k8s.io---` to `rbac.authorization.k8s.io\n---`
sed -i '' 's/rbac.authorization.k8s.io---/rbac.authorization.k8s.io\n---/g' cloudstack/compute/clusterapi/cloudstack-csi-driver.yaml
kubectl apply -f cloudstack/compute/clusterapi/cloudstack-csi-driver.yaml
rm cloudstack/compute/clusterapi/cloudstack-csi-driver.yaml

# Install Cilium CNI with advanced features
cilium install --version 1.18.4 \
    --set kubeProxyReplacement=true \
    --set bgpControlPlane.enabled=true \
    --set encryption.enabled=true \
    --set encryption.type=wireguard \
    --set encryption.nodeEncryption=true \
    --set gatewayAPI.enabled=true \
    --set ingressController.enabled=true \
    --set l2announcements.enabled=true \
    --set l2podAnnouncements.enabled=true \
    --set l7Proxy=true \
    --set ipam.mode=cluster-pool \
    --set ipam.operator.clusterPoolIPv4PodCIDRList={10.168.0.0/16} \
    --set ipam.operator.clusterPoolIPv4MaskSize=24
cilium status --wait

kubectl config use-context admin@homecloud-ops-cks
clusterctl describe cluster homecloud-cks
kubectl config use-context homecloud-cks-admin@homecloud-cks
```

## Updating a Workload Cluster

WIP

## Updating Workload Cluster Image Templates

### Worker Nodes

Follow the steps below to update a workload cluster created using the management cluster:

1. Edit the `CloudStackMachineTemplate` resource for the worker nodes yaml file used to create the workload cluster (e.g., `cloudstack/compute/clusterapi/homecloud-cks-cluster-spec.yaml`) with the new name and spec values for template, offering, and/or ssh key pair.
2. Update the `CloudStackMachineTemplate` reference in the `MachineDeployment` resource section of the yaml file to point to the new template created in step 1.
3. Apply the updated yaml file to the management cluster:

   ```sh
   kubectl --context admin@homecloud-ops-cks apply -f cloudstack/compute/clusterapi/homecloud-cks-cluster-spec.yaml
   ```

4. You can use `k9s` to monitor the rollout of the new worker nodes. Once the new nodes are ready, the cloudstack cloud controller will automatically drain and delete the old nodes.

```sh
k9s --context homecloud-cks-admin@homecloud-cks
```

### Control Plane Nodes

Follow the steps below to update the control plane nodes of a workload cluster created using the management cluster:

1. Edit the `CloudStackMachineTemplate` resource for the control plane nodes in the yaml file used to create the workload cluster (e.g., `cloudstack/compute/clusterapi/homecloud-cks-cluster-spec.yaml`) with the new name and spec valudes for template, offering, and/or ssh key pair.
2. Update the `CloudStackMachineTemplate` reference in the `KubeadmControlPlane` resource section of the yaml file to point to the new template created in step 1.
3. Apply the updated yaml file to the management cluster:

   ```sh
   kubectl --context admin@homecloud-ops-cks apply -f cloudstack/compute/clusterapi/homecloud-cks-cluster-spec.yaml
   ```

4. You can use `k9s` to monitor the rollout of the new control plane nodes. It is very likely that the old control plane will not be automatically drained and deleted, so you may need to manually drain and delete the old control plane nodes once the new nodes are ready. When looking at the `nodes` in `k9s`, the control plane nodes to be drained and deleted can be identified by their red color. Make sure to set the following parameters when draining the nodes to avoid issues, `force=true`, `ignore-daemonsets=true`, and `delete-emptydir-data=true` (the node would have already been drained during the deployment).

```sh
k9s --context homecloud-cks-admin@homecloud-cks
```

## Deleting a Workload Cluster

To delete a workload cluster created using the management cluster ensure the management cluster context is set and the yaml file used to create the workload cluster is available, run the following command:

```sh
kubectl config use-context admin@homecloud-ops-cks
kubectl delete -f cloudstack/compute/clusterapi/homecloud-cks-cluster-spec.yaml
```
