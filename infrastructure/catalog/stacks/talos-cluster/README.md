# talos-cluster

Deploys a production-grade Talos Kubernetes cluster on CloudStack KVM with full
bootstrap automation including CNI, CCM, CSI, and optional platform components.

## Description

This stack orchestrates a complete 8-step bootstrap sequence:

| Step | Resource | Description |
|------|----------|-------------|
| 1 | `cloudstack_ipaddress.lb` | Allocate a public IP for the API server LB |
| 2 | `module.talos_config` | Generate Talos machine secrets and machine configs |
| 3 | `module.control_plane_vms` | Deploy control plane VMs with rendered machine configs |
| 4 | `cloudstack_loadbalancer_rule.apiserver` | Create TCP 6443 LB rule with CP VMs as members |
| 5 | `module.bootstrap` | Bootstrap etcd, wait for health, install Helm charts |
| 6 | `module.worker_vms` | Deploy worker VMs (after bootstrap so they join immediately) |
| 7 | `module.op_talosconfig` | Store talosconfig in 1Password |
| 8 | `module.op_kubeconfig` | Store kubeconfig in 1Password |

### Two cluster flavours

| Variable | ops-cluster | workload-cluster |
|----------|-------------|------------------|
| `is_ops` | `true` | `false` |
| `network_id` | isolated net (`iso-net-shared`) | VPC net (`pub-net-1`) |
| `vpc_id` | `""` | `<vpc-uuid>` |
| `controlplane_count` | `1` | `1` |
| `worker_count` | `2` | `3` |
| `enable_argocd` | `true` | `false` |
| `enable_cloudstack_ccm` | `true` | `true` |
| `enable_cloudstack_csi` | `true` | `true` |
| `enable_external_dns` | `false` | `true` |
| `enable_cert_manager` | `false` | `true` |

## Usage

```hcl
# ops-cluster terragrunt.hcl inputs
inputs = {
  cluster_name        = "ops"
  is_ops              = true
  zone_id             = "uuid-of-zone"
  network_id          = "iso-net-shared-uuid"
  template_id         = "talos-v1.12.6-template-uuid"
  keypair_name        = "nulcell"
  compute_offering_id = "uuid-of-service-offering"
  controlplane_count  = 1
  worker_count        = 2
  enable_argocd       = true
}

# workload-cluster terragrunt.hcl inputs
inputs = {
  cluster_name            = "workload"
  is_ops                  = false
  zone_id                 = "uuid-of-zone"
  network_id              = "pub-net-1-uuid"
  vpc_id                  = "uuid-of-vpc"
  template_id             = "talos-v1.12.6-template-uuid"
  keypair_name            = "nulcell"
  compute_offering_id     = "uuid-of-service-offering"
  controlplane_count      = 1
  worker_count            = 3
  enable_argocd           = false
  enable_cloudstack_ccm   = true
  enable_cloudstack_csi   = true
  enable_external_dns     = true
  enable_cert_manager     = true
  cloudflare_zone         = "example.com"
}
```

## Inputs

| Name | Type | Description | Default | Required |
|------|------|-------------|---------|----------|
| `cloudstack_api_url` | `string` | CloudStack API endpoint URL. | – | yes |
| `zone_id` | `string` | UUID of the CloudStack zone. | – | yes |
| `zone_name` | `string` | Name of the CloudStack zone. | `"zone-homecloud"` | no |
| `account_name` | `string` | CloudStack account name. | `"homecloud"` | no |
| `domain_id` | `string` | UUID of the CloudStack domain. | `""` | no |
| `network_id` | `string` | Primary network UUID for cluster nodes. | – | yes |
| `vpc_id` | `string` | VPC UUID for public IP allocation. | `""` | no |
| `template_id` | `string` | UUID of the Talos Linux VM template. | – | yes |
| `keypair_name` | `string` | SSH keypair name. | – | yes |
| `compute_offering_id` | `string` | UUID of the service offering. | – | yes |
| `cluster_name` | `string` | Name of the cluster. | – | yes |
| `is_ops` | `bool` | True for ops cluster. | `false` | no |
| `controlplane_count` | `number` | Number of control plane nodes. | `1` | no |
| `worker_count` | `number` | Number of worker nodes. | `1` | no |
| `control_plane_disk_size` | `number` | Control plane root disk size (GB). | `30` | no |
| `worker_disk_size` | `number` | Worker root disk size (GB). | `50` | no |
| `kubernetes_version` | `string` | Kubernetes version. | `"1.32.0"` | no |
| `talos_version` | `string` | Talos version. | `"v1.12.6"` | no |
| `talos_config_patches` | `list(string)` | Talos config patches for control plane. | `[]` | no |
| `enable_argocd` | `bool` | Install ArgoCD. | `false` | no |
| `enable_cloudstack_ccm` | `bool` | Install CloudStack CCM. | `true` | no |
| `enable_cloudstack_csi` | `bool` | Install CloudStack CSI. | `true` | no |
| `enable_external_dns` | `bool` | Install external-dns. | `false` | no |
| `enable_cert_manager` | `bool` | Install cert-manager. | `false` | no |
| `cloudflare_zone` | `string` | Cloudflare DNS zone name. | `""` | no |
| `argocd_server_url` | `string` | ArgoCD server URL (for workload cluster). | `""` | no |
| `op_vault` | `string` | 1Password vault name or UUID. | `"homecloud"` | no |
| `cilium_version` | `string` | Cilium chart version. | `"1.17.0"` | no |
| `ccm_version` | `string` | CloudStack CCM chart version. | `"0.4.0"` | no |
| `csi_version` | `string` | CloudStack CSI chart version. | `"0.4.0"` | no |
| `argocd_version` | `string` | ArgoCD chart version. | `"7.8.0"` | no |
| `cert_manager_version` | `string` | cert-manager chart version. | `"1.17.0"` | no |
| `external_dns_version` | `string` | external-dns chart version. | `"8.7.1"` | no |

## Outputs

| Name | Description | Sensitive |
|------|-------------|-----------|
| `cluster_endpoint` | Kubernetes API server endpoint. | no |
| `lb_ip` | Public IP of the load balancer. | no |
| `kubeconfig` | Kubeconfig YAML. | yes |
| `talosconfig` | Talosconfig YAML. | yes |
| `control_plane_vm_ids` | UUIDs of control plane VMs. | no |
| `worker_vm_ids` | UUIDs of worker VMs. | no |
| `argocd_server_url` | ArgoCD URL (set when `enable_argocd = true`). | no |

## Notes

- **No helm/kubernetes provider in providers.tf** – Helm charts are installed via
  `null_resource` + `local-exec` in the `kubernetes-bootstrap` module.  The `helm`
  CLI must be on `$PATH`.
- **1Password items** – `module.op_talosconfig` and `module.op_kubeconfig` write
  cluster credentials to 1Password after bootstrap.  The items must not already
  exist or the 1Password provider will error on the plan-time `data` read.
  Create placeholder items manually before the first apply, or use a two-pass apply.
- **Machine secrets in state** – All Talos PKI material is in Terraform state.
  Use an encrypted remote backend.
