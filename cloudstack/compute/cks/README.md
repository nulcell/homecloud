# CloudStack Kubernetes Service (CKS)

## Creating a CKS ISO

On the CloudStack management server, the following commands can be used to create a CKS ISO. Calico is used as the CNI plugin in this example because it can be easily installed via a single YAML manifest, same with the older version of Kubernetes Dashboard.
It is possible to modify the script to generate yaml configs using helm.

It is advisable to use the cilium CNI plugin for better performance and security. Instructions for generating a CKS ISO with Cilium as the CNI plugin are provided after the Calico example or you can use the CNI config located at `cloudstack/cni-config/cilium.yaml` to deploy Cilium during cluster creation with Helm.

```shell
OUTPUT_PATH=/tmp/
KUBERNETES_VERSION="1.34.2"
CNI_VERSION="1.8.0"
CRICTL_VERSION="1.34.0"
WEAVENET_NETWORK_YAML_CONFIG="https://raw.githubusercontent.com/projectcalico/calico/v3.31.1/manifests/calico.yaml"
DASHBOARD_YAML_CONFIG="https://raw.githubusercontent.com/kubernetes/dashboard/v2.7.0/aio/deploy/recommended.yaml"
BUILD_NAME="v${KUBERNETES_VERSION}-cks-calico"
ARCH="amd64"
ETCD_VERSION="3.5.0"
sudo apt install -y wget curl genisoimage containerd.io
/usr/share/cloudstack-common/scripts/util/create-kubernetes-binaries-iso.sh \
    $OUTPUT_PATH \
    $KUBERNETES_VERSION \
    $CNI_VERSION \
    $CRICTL_VERSION \
    $WEAVENET_NETWORK_YAML_CONFIG \
    $DASHBOARD_YAML_CONFIG \
    $BUILD_NAME \
    $ARCH \
    $ETCD_VERSION
```

Alternatively, there is a modified builder script of the original script located at `/usr/share/cloudstack-common/scripts/util/create-kubernetes-binaries-iso.sh` found on the CloudStack management server, [source](https://raw.githubusercontent.com/apache/cloudstack/refs/heads/main/scripts/util/create-kubernetes-binaries-iso.sh), to support helm and cilium as the CNI plugin.

```shell
OUTPUT_PATH=./
KUBERNETES_VERSION="1.34.2"
CNI_VERSION="1.8.0"
CRICTL_VERSION="1.34.0"
CILIUM_VERSION="1.18.2"
DASHBOARD_YAML_CONFIG="https://raw.githubusercontent.com/kubernetes/dashboard/v2.7.0/aio/deploy/recommended.yaml"
BUILD_NAME="v${KUBERNETES_VERSION}-cks-cilium"
ARCH="amd64"
ETCD_VERSION="3.5.0"
sudo apt install -y wget curl genisoimage containerd.io helm
./create-cilium-kubernetes-binaries-iso.sh \
    $OUTPUT_PATH \
    $KUBERNETES_VERSION \
    $CNI_VERSION \
    $CRICTL_VERSION \
    $CILIUM_VERSION \
    $DASHBOARD_YAML_CONFIG \
    $BUILD_NAME \
    $ARCH \
    $ETCD_VERSION
```

Once the cluster is up, update the Cilium configuration to be managed by Helm:

```shell
CILIUM_VERSION="1.18.2"
helm repo add cilium https://helm.cilium.io/
helm upgrade --install cilium cilium/cilium --version ${CILIUM_VERSION} \
  --namespace kube-system \
  --set kubeProxyReplacement=true \
  --take-ownership
```

__Note__:

- If you run into an error regarding `ctr not found`, ensure that `containerd` is installed on the  server where you are executing the script, by following the instructions on [Docker](https://docs.docker.com/engine/install/ubuntu/#install-using-the-repository).
- If using the Cilium CNI image generator, ensure that `helm` sources are configured properly by following the instructions on [Helm](http://helm.sh/docs/intro/install/#from-apt-debianubuntu).

The ISO can then be uploaded to CloudStack as a Kubernetes ISO image.
