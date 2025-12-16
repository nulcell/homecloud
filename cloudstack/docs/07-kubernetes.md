# Kubernetes Cluster Configuration

## Prerequisites

- A running Kubernetes Cluster on CloudStack (refer to [Homecloud Guide](./01-homecloud.md))
- Access to Kubernetes admin credentials
- The following tools installed on your local machine:
  - `kubectl`
  - `helm`
  - `cilium`
  - `istioctl` (if using Istio)
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
helm upgrade --install cilium cilium/cilium --version 1.18.4 --namespace kube-system \
      --set kubeProxyReplacement=true \
      --set bgpControlPlane.enabled=true \
      --set encryption.enabled=true \
      --set encryption.type=wireguard \
      --set encryption.nodeEncryption=true \
      --set gatewayAPI.enabled=false \
      --set ingressController.enabled=false \
      --set l2announcements.enabled=true \
      --set l2podAnnouncements.enabled=true \
      --set l7Proxy=false \
      --set socketLB.hostNamespaceOnly=true \
      --set cni.exclusive=true \
      --set ipam.mode=cluster-pool \
      --set ipam.operator.clusterPoolIPv4PodCIDRList={10.168.0.0/16} \
      --set ipam.operator.clusterPoolIPv4MaskSize=24 \
      --set hubble.relay.enabled=false \
      --set hubble.ui.enabled=false
```

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
  name: cloudflare-dns-token
  namespace: traefik
spec:
  itemPath: "vaults/homecloud-k8s/items/Cloudflare DNS Token"
---
EOF
```

```sh
helm dependency update ./kubernetes/charts/traefik
helm upgrade --install traefik ./kubernetes/charts/traefik --namespace traefik --create-namespace \
  --set "traefik.additionalArguments[0]=--certificatesresolvers.le.acme.email=$(op read "op://homecloud/.env/General/SSL_EMAIL")" \
  --set "traefik.additionalArguments[1]=--certificatesresolvers.le.acme.storage=/data/acme.json" \
  --set "traefik.additionalArguments[2]=--certificatesresolvers.le.acme.dnschallenge.provider=cloudflare" \
  --set "traefik.additionalArguments[3]=--certificatesResolvers.le.acme.dnsChallenge.resolvers=1.1.1.1:53" \
  --set "traefik.additionalArguments[4]=--api=true" \
  --set "traefik.ingressRoute.dashboard.matchRule=Host(\`traefik.dev.$(op read "op://homecloud/.env/General/DOMAIN_NAME")\`)" \
  --set "traefik.env[0].name=CF_DNS_API_TOKEN" \
  --set "traefik.env[0].valueFrom.secretKeyRef.name=cloudflare-dns-token" \
  --set "traefik.env[0].valueFrom.secretKeyRef.key=credential" \
  --set "traefik.env[1].name=CF_API_EMAIL" \
  --set "traefik.env[1].valueFrom.secretKeyRef.name=cloudflare-dns-token" \
  --set "traefik.env[1].valueFrom.secretKeyRef.key=username"
```

### knative (Optional)

```sh
helm repo add knative-operator https://knative.github.io/operator
helm repo update
helm install knative-operator --create-namespace --namespace knative-operator knative-operator/knative-operator --version v1.20.0
kubectl apply -f https://raw.githubusercontent.com/nulcell/homecloud/refs/heads/main/kubernetes/charts/wip/knative/templates/knative-serving.yaml
kubectl apply -f https://raw.githubusercontent.com/nulcell/homecloud/refs/heads/main/kubernetes/charts/wip/knative/templates/knative-eventing.yaml
```

## Applications

### n8n

```sh
...
```
