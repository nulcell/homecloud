# kubernetes-bootstrap

Bootstraps a Talos Kubernetes cluster and installs core platform components via Helm.

## Description

This module performs the complete post-VM bootstrap sequence for a Talos cluster:

1. **`talos_machine_bootstrap`** – triggers etcd bootstrap on the first control plane node.
   `lifecycle { ignore_changes = all }` prevents re-bootstrapping on subsequent applies.
2. **`data "talos_cluster_health"`** – polls until all nodes report healthy (timeout: 15 min).
3. **`data "talos_cluster_kubeconfig"`** – retrieves the admin kubeconfig (timeout: 10 min).
4. **`local_sensitive_file`** – writes kubeconfig to `${path.root}/.kube/<cluster_name>.kubeconfig`
   with mode `0600`.
5. **Helm installs** (via `null_resource` + `local-exec`):
   - **Cilium** (always) – CNI with kube-proxy replacement
   - **CloudStack CCM** (conditional: `enable_ccm`) – cloud controller manager
   - **CloudStack CSI** (conditional: `enable_csi`) – storage driver
   - **ArgoCD** (conditional: `enable_argocd`) – GitOps controller
   - **cert-manager** (conditional: `enable_cert_manager`) – TLS certificate automation
   - **external-dns** (conditional: `enable_external_dns`) – DNS record automation

### Why `null_resource` instead of `helm_release`?

The Helm provider must be configured with a `host`, `cluster_ca_certificate`, and
client credentials.  These values are only known *after* the cluster is bootstrapped
(i.e. they come from `data "talos_cluster_kubeconfig"`).  Because Terraform provider
configuration cannot reference resource or module outputs, using `helm_release` would
require a separate provider block with hardcoded credentials or a multi-stage apply.

Using `null_resource` + `local-exec` with the `helm` CLI sidesteps this limitation:
the kubeconfig is written to disk first, then Helm reads it via `--kubeconfig`.

### Prerequisite

The `helm` CLI must be installed and on `$PATH` on the machine running Terraform.

## Usage

```hcl
module "bootstrap" {
  source = "../../modules/kubernetes-bootstrap"

  cluster_name         = "ops"
  cluster_endpoint     = "https://10.10.10.10:6443"
  client_configuration = module.talos_config.client_configuration
  controlplane_ips     = ["10.10.10.11"]
  worker_ips           = ["10.10.10.12", "10.10.10.13"]

  enable_argocd        = true
  enable_ccm           = false
  enable_csi           = false

  cilium_version       = "1.17.0"
  argocd_version       = "7.8.0"

  cloudstack_api_url    = "https://cloudstack.example.com/client/api"
  cloudstack_api_key    = "..."
  cloudstack_secret_key = "..."
  cloudstack_zone_name  = "zone-homecloud"
}
```

## Inputs

| Name | Type | Description | Default | Required |
|------|------|-------------|---------|----------|
| `cluster_name` | `string` | Cluster name; used for kubeconfig filename. | – | yes |
| `cluster_endpoint` | `string` | Kubernetes API endpoint (https://\<IP\>:6443). | – | yes |
| `client_configuration` | `object` | Talos client configuration (ca, crt, key). | – | yes |
| `controlplane_ips` | `list(string)` | Private IPs of control plane nodes. | – | yes |
| `worker_ips` | `list(string)` | Private IPs of worker nodes. | `[]` | no |
| `enable_argocd` | `bool` | Install ArgoCD. | `false` | no |
| `enable_cert_manager` | `bool` | Install cert-manager. | `false` | no |
| `enable_external_dns` | `bool` | Install external-dns. | `false` | no |
| `enable_csi` | `bool` | Install CloudStack CSI driver. | `true` | no |
| `enable_ccm` | `bool` | Install CloudStack CCM. | `true` | no |
| `cilium_version` | `string` | Cilium chart version. | `"1.17.0"` | no |
| `ccm_version` | `string` | CloudStack CCM chart version. | `"0.4.0"` | no |
| `csi_version` | `string` | CloudStack CSI chart version. | `"0.4.0"` | no |
| `argocd_version` | `string` | ArgoCD chart version. | `"7.8.0"` | no |
| `cert_manager_version` | `string` | cert-manager chart version. | `"1.17.0"` | no |
| `external_dns_version` | `string` | external-dns chart version. | `"8.7.1"` | no |
| `cloudstack_api_url` | `string` | CloudStack API URL (for CCM/CSI). | – | yes |
| `cloudstack_api_key` | `string` | CloudStack API key (sensitive). | – | yes |
| `cloudstack_secret_key` | `string` | CloudStack secret key (sensitive). | – | yes |
| `cloudstack_zone_name` | `string` | CloudStack zone name (for CCM/CSI). | – | yes |
| `cloudflare_api_token` | `string` | Cloudflare API token for external-dns. | `""` | no |
| `cloudflare_zone_ids` | `map(string)` | Map of DNS zone → Cloudflare zone ID. | `{}` | no |

## Outputs

| Name | Description | Sensitive |
|------|-------------|-----------|
| `kubeconfig` | Raw kubeconfig YAML. | yes |
| `kubeconfig_path` | Local path where kubeconfig was written. | no |
| `cluster_ca` | Cluster CA certificate (base64). | no |
| `client_cert` | Admin client certificate (base64). | yes |
| `client_key` | Admin client key (base64). | yes |
| `endpoint` | Kubernetes API server endpoint. | no |
