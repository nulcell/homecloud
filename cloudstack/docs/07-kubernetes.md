# Kubernetes Cluster Configuration

## Prerequisites

- A running Kubernetes Cluster on CloudStack (refer to [Homecloud Guide](./01-homecloud.md))
- Access to Kubernetes admin credentials
- The following tools installed on your local machine:
  - `kubectl`
  - `helm`
  - `cilium`
  - `op` (1Password CLI)
  - `k9s` (optional)

## Post-Deployment Steps

### Kubernetes Dashboard

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

### CloudStack CSI StorageClass

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
allowVolumeExpansion: true
parameters:
  csi.cloudstack.apache.org/disk-offering-id: $(cmk list diskofferings state=active name=acs.disk.shared.custom | jq -r ".diskoffering[0].id")
EOF
```

### Verification

```sh
kubectl get pods -n kube-system | grep cilium
kubectl get csidrivers.storage.k8s.io
kubectl get csinodes.storage.k8s.io
kubectl get storageclasses.storage.k8s.io
cilium status
```

## Core Infrastructure Setup

### Cilium CNI

Cilium is used as the CNI for networking. It should have been installed during cluster setup. Verify its status:

```sh
cilium status --wait
```

Make changes with helm if needed. When using Istio, take note of the points made in the [Integration with Istio Guide](https://docs.cilium.io/en/latest/network/servicemesh/istio/)

```sh
helm dependency update ./charts/cilium
helm upgrade --install cilium ./charts/cilium --version 1.18.4 --namespace kube-system
```

Note: If the deployment gets stuck when you run `cilium status --wait`, you may need to restart the Cilium pods or uninstall first using `helm uninstall cilium -n kube-system` and then reinstall.

### Metrics Server

```sh
helm repo add metrics-server https://kubernetes-sigs.github.io/metrics-server/
helm repo update
helm upgrade --install metrics-server metrics-server/metrics-server --namespace kube-system \
    --version 3.13.0 \
    --set "containerPort=4443" \
    --set "hostNetwork.enabled=true" \
    --set "metrics.enabled=true" \
    --set "defaultArgs[0]=--cert-dir=/tmp" \
    --set "defaultArgs[1]=--secure-port=4443" \
    --set "defaultArgs[2]=--kubelet-preferred-address-types=InternalIP\,ExternalIP\,Hostname" \
    --set "defaultArgs[3]=--kubelet-use-node-status-port" \
    --set "defaultArgs[4]=--metric-resolution=15s" \
    --set "defaultArgs[5]=--kubelet-insecure-tls"
```

### 1Password Operator

Guides:

- [Secrets Automation Workflow](https://developer.1password.com/docs/connect/get-started/?deploy=kubernetes&method=1password-cli#step-1)
- [Kubernetes Operator](https://developer.1password.com/docs/k8s/operator)

Create a connect server with the first guide, if you don't have one already, then install the operator with the commands below:

(Save the generated `1password-credentials.json` file to 1Password)

```sh
# Create 1Password connect server
op connect server create homecloud-connect-server --vaults homecloud-k8s
```

```sh
# Install 1Password operator
helm repo add 1password https://1password.github.io/connect-helm-charts/
helm repo update
helm upgrade --install connect 1password/connect \
    --namespace 1password \
    --create-namespace \
    --version 2.1.1 \
    --set-file connect.credentials=1password-credentials.json \
    --set operator.create=true \
    --set operator.token.value=$(op connect token create homecloud-k8s-token --server homecloud-connect-server --vault homecloud-k8s)
```

### External DNS

For managing DNS records automatically with Cloudflare, External DNS is used. A Secret for the Cloudflare API token is needed using 1Password.

```sh
kubectl apply -f - <<EOF
apiVersion: v1
kind: Namespace
metadata:
  name: external-dns
---
apiVersion: onepassword.com/v1
kind: OnePasswordItem
metadata:
  name: cloudflare-api-token
  namespace: external-dns
spec:
  itemPath: "vaults/homecloud-k8s/items/Cloudflare DNS API Token"
---
EOF
```

```sh
helm dependency update ./charts/external-dns
helm upgrade --install external-dns ./charts/external-dns --namespace external-dns --create-namespace --version 1.19.0
```

### Traefik

For creating valid SSL certificates using Let's Encrypt and Cloudflare DNS challenge a Secret for the Cloudflare API token is needed using 1Password.

```sh
kubectl apply -f - <<EOF
apiVersion: v1
kind: Namespace
metadata:
  name: traefik
---
apiVersion: onepassword.com/v1
kind: OnePasswordItem
metadata:
  name: cloudflare-api-token
  namespace: traefik
spec:
  itemPath: "vaults/homecloud-k8s/items/Cloudflare DNS API Token"
---
EOF
```

```sh
helm dependency update ./charts/traefik
helm upgrade --install traefik ./charts/traefik --namespace traefik --create-namespace --version 37.4.0
```

### Monitoring Stack (For Operations Cluster)

```sh
helm dependency update ./charts/monitoring
helm upgrade --install monitoring ./charts/monitoring --namespace monitoring --create-namespace --version 1.0.0
```

### Cloud Native PG

[Installation guide](https://cloudnative-pg.io/documentation/current/installation_upgrade/)

```sh
helm repo add cnpg https://cloudnative-pg.github.io/charts
helm repo update
helm upgrade --install cnpg cnpg/cloudnative-pg \
  --namespace cnpg-system \
  --create-namespace \
  --version 0.27.0 \
  --set config.clusterWide=true
```

Create a sample PostgreSQL cluster:

```sh
helm upgrade --install dev-pg-cluster cnpg/cluster \
    --namespace database \
    --create-namespace \
    --version 0.4.0 \
    --set type=postgresql \
    --set version.postgresql=18.1 \
    --set mode=standalone \
    --set backups.enabled=false \
    --set cluster.instances=3 \
    --set cluster.storage.size=1Gi \
    --set cluster.storage.storageClass=cloudstack-custom-disk-offering \
    --set cluster.initdb.database=homecloud \
    --set cluster.initdb.owner=homecloud_admin \
    --set "databases[0].name=tesing_db" \
    --set "databases[0].owner=homecloud_admin"
```

### Bastion Host

For general operations, it's recommended to set up a bastion host within the Kubernetes cluster. This host can be used to access internal services securely.

```sh
kubectl apply -f ./kubernetes/bastion.yaml
```

## Applications

### n8n

```sh
helm dependency update ./charts/n8n
helm upgrade --install n8n ./charts/n8n --namespace n8n --create-namespace --version 0.0.1
```

### Homepage

```sh
...
```

### Uptime Kuma

```sh
...
```

### Media Server

```sh
...
```
