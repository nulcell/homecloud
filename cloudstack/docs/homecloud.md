# HomeCloud Environment Setup

## Project Structure

### Domains

Generally avoid using the root domain for activities other than creating images, ISOs, roles, offerings, accounts, and projects.

| Name | Network Domain |
|------|----------------|
| `homecloud` | homecloud.internal |

### Accounts & Users

Create the homecloud account that will own the resources for each environment. You can also create additional users under this account as needed.

| Role | Username | Domain | Account | Timezone |
|------|----------|--------|---------|----------|
| Domain Admin | `homecloud-admin` | homecloud | `homecloud` | Europe/Amsterdam |

### Projects

Sign in as the `homecloud-admin` user to create the following projects under the `homecloud` domain. These projects will own the resources for each environment.

| Name | Description |
|------|-------------|
| `homecloud-prod` | Homecloud Production Environment |
| `homecloud-sand` | Homecloud Sandbox Environment |
| `homecloud-dev` | Homecloud Development Environment |

## Networking Configuration

### VPC Networks

You should be creating these in a project under a dedicated domain (or root domain if you don't want to create a new domain) for your CloudStack environment.

**Note**:

- Values for DNS1 & DNS2 can be left empty to use CloudStack's default DNS settings for the zone.
- Use the following CIDR with the following subnets (use custom ACLs depending on the services being deployed in each network):
  - VPC CIDR: `10.0.0.0/24` (i.e., 256 IP addresses)
    - Network 1:
      - name: `pub-net-1` (the vpc name will be prefixed automatically when **vpc.tier.name.prepend** is set to true in global settings)
      - network offering: `acs.net.vpc.core-public-lb` (VPC Network with VpcVirtualRouter and Public LB)
      - gateway: `10.0.0.1`
      - netmask: `255.255.255.192` (i.e., /26)
      - acl: default-allow
    - Network 2:
      - name: `priv-net-1` (the vpc name will be prefixed automatically when **vpc.tier.name.prepend** is set to true in global settings)
      - network offering: `acs.net.vpc.core-internal-lb-vm` (VPC Network with VpcVirtualRouter and Internal LB VM)
      - gateway: `10.0.0.65`
      - netmask: `255.255.255.192` (i.e., /26)
      - acl: default-allow
    - Network 3:
      - name: `priv-net-2` (the vpc name will be prefixed automatically when **vpc.tier.name.prepend** is set to true in global settings)
      - network offering: `acs.net.vpc.core-internal-lb-vm` (VPC Network with VpcVirtualRouter and Internal LB VM)
      - gateway: `10.0.0.129`
      - netmask: `255.255.255.192` (i.e., /26)
      - acl: default-allow
    - Network 4:
      - name: `priv-net-3` (the vpc name will be prefixed automatically when **vpc.tier.name.prepend** is set to true in global settings)
      - network offering: `acs.net.vpc.core-internal-lb-vm` (VPC Network with VpcVirtualRouter and Internal LB VM)
      - gateway: `10.0.0.193`
      - netmask: `255.255.255.192` (i.e., /26)
      - acl: default-allow

| Name | Description | Network Domain | VPC Offering | IPv4 address for the VR in this Network | Networks |
|------|-------------|----------------|--------------|-----------------------------------------|----------|
| `homecloud-vpc-prod` | Homecloud VPC Production Network | homecloud-prod.internal | `acs.vpc.natted.redundant-core` | N/A | Network 1, Network 2, Network 3, Network 4 |
| `homecloud-vpc-sand` (optional) | Homecloud VPC Sandbox Network | homecloud-sand.internal | `acs.vpc.natted.redundant-core` | N/A | Network 1, Network 2, Network 3, Network 4 |
| `homecloud-vpc-dev` | Homecloud VPC Development Network | homecloud-dev.internal | `acs.vpc.natted.core`/`acs.vpc.natted.redundant-core` | N/A | Network 1, Network 2 |

### Kubernetes Cluster

Create a Kubernetes cluster in the environment VPC using whatever version. Pass the relevant CNI configuration for Cilium with the most recent supported version.

| Name | Description | Zone | Hypervisor | Kubernetes version | Compute Offering | Node root disk size (in GB) | Network | HA enabled | Cluster size (Worker nodes) | SSH key pair | Show advanced settings | Enable CloudStack CSI Driver | Service Offering for Control Nodes | Template for Control Nodes | Service Offering for Worker Nodes | Template for Worker Nodes | Etcd Nodes | Service Offering for etcd Nodes | Template for etcd Nodes | CNI Configuration | CNI Configuration Parameters | Auto Scaling  | Min Nodes | Max Nodes |
|------|-------------|------|------------|--------------------|------------------|-----------------------------|---------|------------|------------|---------------------------|--------------|------------------------|-------------------------------|----------------------------|-----------------------------|----------------------------|-------------------------|------------|------------------------------|-------------------------|-------------------|--------------|----------|----------|
| `homecloud-cks-cluster-prod` | Homecloud Production Kubernetes Cluster | `zone-homecloud` | KVM | 1.34.2 | acs.comp.gen.medium | 200 | homecloud-vpc-prod_net-1 | true | 3 | _your-ssh-key_ | true | true | acs.comp.mem.medium | None | acs.comp.mem.medium | None | 3 | acs.comp.mem.medium | None | cilium | cilium_version: `1.18.2` | true | 3 | 10 |
| `homecloud-cks-cluster-sand` | Homecloud Sandbox Kubernetes Cluster | `zone-homecloud` | KVM | 1.34.2 | acs.comp.gen.medium | 100 | homecloud-vpc-sand_net-1 | true | 3 | _your-ssh-key_ | true | true | acs.comp.mem.medium | None | acs.comp.mem.medium | None | 1 | acs.comp.mem.medium | None | cilium | cilium_version: `1.18.2` | true | 1 | 3 |
| `homecloud-cks-cluster-dev` | Homecloud Development Kubernetes Cluster |  `zone-homecloud` | KVM | 1.34.2 | acs.comp.gen.small | 75 | homecloud-vpc-dev_net-1 | false | 3 | _your-ssh-key_ | true | true | acs.comp.gen.small | None | acs.comp.gen.small | None | 0 | N/A | N/A | cilium | cilium_version: `1.18.2` | false | N/A | N/A |

Note:

- When using the CloudStack CSI, be aware of the requirements on [GitHub](https://github.com/apalia/cloudstack-csi-driver?tab=readme-ov-file#requirements)

Post-deployment steps:

- Access the cluster via kubectl using the kubeconfig file downloaded from CloudStack UI (you can import it to `kubectl` using `kubectl konfig import -s ~/Downloads/kube.conf`)
- Access the Kubernetes Dashboard:
  - Create the token:

    ```sh
    kubectl apply -f - <<EOF
    apiVersion: v1
    kind: ServiceAccount
    metadata:
      name: kubernetes-dashboard-admin-user
      namespace: kubernetes-dashboard
    ---
    apiVersion: rbac.authorization.k8s.io/v1
    kind: ClusterRoleBinding
    metadata:
      name: kubernetes-dashboard-admin-user
    roleRef:
      apiGroup: rbac.authorization.k8s.io
      kind: ClusterRole
      name: cluster-admin
    subjects:
    - kind: ServiceAccount
      name: kubernetes-dashboard-admin-user
      namespace: kubernetes-dashboard
    ---
    apiVersion: v1
    kind: Secret
    type: kubernetes.io/service-account-token
    metadata:
      name: kubernetes-dashboard-token
      namespace: kubernetes-dashboard
      annotations:
        kubernetes.io/service-account.name: kubernetes-dashboard-admin-user
    EOF
    ```

  - Get the token:

    ```sh
    kubectl describe secret $(kubectl get secrets -n kubernetes-dashboard | grep kubernetes-dashboard-token | awk '{print $1}') -n kubernetes-dashboard | grep "token:" | awk '{print $2}'
    ```

  - Start kube proxy and go to `http://localhost:8001/api/v1/namespaces/kubernetes-dashboard/services/https:kubernetes-dashboard:/proxy/`:

    ```sh
    kubectl proxy
    ```

- Configure the CloudStack CSI StorageClass as the default StorageClass (optional):

  ```sh
  kubectl apply -f - <<EOF
  apiVersion: storage.k8s.io/v1
  kind: StorageClass
  metadata:
    name: cloudstack-custom-disk-offering
    annotations:
      storageclass.kubernetes.io/is-default-class: "true"
  provisioner: csi.cloudstack.apache.org
  reclaimPolicy: Delete
  volumeBindingMode: WaitForFirstConsumer
  allowVolumeExpansion: false
  parameters:
    csi.cloudstack.apache.org/disk-offering-id: $(cmk list diskofferings state=active name=acs.disk.shared.custom | jq -r ".diskoffering[0].id")
  EOF
  ```

- Verify Cilium is installed and running correctly:

  ```sh
  kubectl get pods -n kube-system | grep cilium
  kubectl get csidrivers.storage.k8s.io
  kubectl get csinodes.storage.k8s.io
  kubectl get storageclasses.storage.k8s.io
  cilium status
  ```

- Update the Cilium configuration:

  ```sh
  helm dependency update ./k8s/apps/cilium
  helm upgrade --install cilium ./k8s/apps/cilium --namespace kube-system
  ```

- (Optional) Install `traefik` via Helm (you can use cilium for most things):

  ```sh
  helm dependency update ./k8s/apps/traefik
  helm upgrade --install traefik ./k8s/apps/traefik --namespace traefik --create-namespace
  ```

  OR

  ```sh
  helm repo add traefik https://traefik.github.io/charts # or https://helm.traefik.io/traefik
  helm repo update
  helm install traefik traefik/traefik --namespace traefik --create-namespace --version 37.3.0
  ```

- (Optional) Install `knative` via Helm if you need serverless capabilities:

  ```sh
  helm repo add knative-operator https://knative.github.io/operator 
  helm repo update
  helm install knative-operator --create-namespace --namespace knative-operator knative-operator/knative-operator --version v1.20.0
  kubectl apply -f https://raw.githubusercontent.com/nulcell/homecloud/refs/heads/main/k8s/apps/knative/templates/knative-serving.yaml
  kubectl apply -f https://raw.githubusercontent.com/nulcell/homecloud/refs/heads/main/k8s/apps/knative/templates/knative-eventing.yaml
  ```

- (Optional & not recommended) If not using CloudStack CSI, install `longhorn` via Helm (note that the kubernetes hosts need to have certain packages installed as defined in the [docs](https://longhorn.io/docs/1.10.1/deploy/install/#installation-requirements), so ideally use a template with the packages already installed if you are to use `longhorn`):

  ```sh
  helm repo add longhorn https://charts.longhorn.io
  helm repo update
  helm install longhorn longhorn/longhorn --namespace longhorn-system --create-namespace --version 1.10.1
  ```

  - You can view the `longhorn` dashboard with `kubectl proxy` at `http://localhost:8001/api/v1/namespaces/longhorn-system/services/http:longhorn-frontend:http/proxy/#/dashboard`

- Install `media-server` app via Helm. Access the `media-server` app at `http://<LOAD_BALANCER_IP>/` (you can get the Load Balancer IP from CloudStack UI or via `kubectl get svc -n media-server`)

  ```sh
  helm dependency update ./k8s/apps/media-server
  helm upgrade --install media-server ./k8s/apps/media-server --namespace media-server --create-namespace
  ```
