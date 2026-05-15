provider "cloudstack" {
  api_url    = var.cloudstack_api_url
  api_key    = local.cs_api_key
  secret_key = local.cs_secret_key
}

provider "talos" {}

# The helm provider is configured per-cluster using the kubeconfig written
# to disk by the kubernetes-bootstrap module (Step 4).
# On initial cluster setup, two applies are required: the first bootstraps
# the cluster and writes the kubeconfig; the second installs Helm charts.
provider "helm" {
  alias = "cluster"
  kubernetes = {
    config_path = "${path.root}/.kube/${var.cluster_name}.kubeconfig"
  }
}

provider "onepassword" {
  account = var.op_account
}
