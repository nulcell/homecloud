# argocd-setup

Registers the workload cluster as a target cluster in ArgoCD running on the ops cluster.

## Description

This stack creates a Kubernetes `Secret` in the `argocd` namespace of the **ops cluster**
with the label `argocd.argoproj.io/secret-type: cluster`.  ArgoCD detects this secret
and makes the workload cluster available for application deployment.

The stack reads the ops cluster kubeconfig from 1Password (written there by the
`talos-cluster` stack) and uses it to configure the Kubernetes provider.

### Prerequisites

1. The ops cluster must be running and healthy.
2. ArgoCD must be installed on the ops cluster (`enable_argocd = true` in the
   `talos-cluster` stack for the ops cluster).
3. The ops cluster kubeconfig must be stored in 1Password as
   `"Kubeconfig - <ops_cluster_name>"` with a field labelled `config`.
4. The `argocd` namespace must exist on the ops cluster.

## Usage

```hcl
# terragrunt.hcl inputs
inputs = {
  op_vault                  = "homecloud"
  ops_cluster_name          = "ops"
  workload_cluster_name     = "workload"
  workload_cluster_endpoint = "https://10.20.30.40:6443"

  # Obtain these from the talos-cluster stack outputs for the workload cluster:
  workload_cluster_ca   = "<base64-ca-cert>"
  workload_cluster_cert = "<base64-client-cert>"
  workload_cluster_key  = "<base64-client-key>"
}
```

## Inputs

| Name | Type | Description | Default | Required |
|------|------|-------------|---------|----------|
| `op_vault` | `string` | 1Password vault name or UUID. | `"homecloud"` | no |
| `ops_cluster_name` | `string` | Ops cluster name (for kubeconfig lookup). | `"ops"` | no |
| `workload_cluster_name` | `string` | Name of the workload cluster to register. | – | yes |
| `workload_cluster_endpoint` | `string` | Kubernetes API URL for the workload cluster. | – | yes |
| `workload_cluster_ca` | `string` | Base64-encoded cluster CA certificate. | – | yes |
| `workload_cluster_cert` | `string` | Base64-encoded client certificate (sensitive). | – | yes |
| `workload_cluster_key` | `string` | Base64-encoded client key (sensitive). | – | yes |

## Outputs

| Name | Description |
|------|-------------|
| `workload_cluster_registered` | `true` once the cluster secret is created. |
| `workload_cluster_name` | Name of the registered workload cluster. |
