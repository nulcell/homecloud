# ops-cluster unit
# Deploys the Talos Linux ops Kubernetes cluster on iso-net-shared (isolated network).
#
# Network placement rationale:
#   CloudStack allows only one public-lb subnet per VPC. The workload cluster takes
#   pub-net-1 (VPC, public-lb). The ops cluster therefore uses iso-net-shared (isolated
#   network with its own virtual router and public IP) to avoid the conflict.
#
# Bootstrap flow:
#   1. Acquire CloudStack public IP (kube-apiserver LB endpoint)
#   2. Create LB rule port 6443 on that IP
#   3. Generate Talos machine secrets + controlplane/worker configs (endpoint = LB IP)
#   4. Deploy Talos VMs with machine config as base64 user_data
#   5. Assign control-plane VMs to LB rule
#   6. Bootstrap etcd via talos provider
#   7. Install Cilium CNI + CloudStack CCM + CSI via helm_release
#   8. Install ArgoCD — manages both ops and workload cluster apps via GitOps
#   9. Write talosconfig + kubeconfig to 1Password

include "root" {
  path = find_in_parent_folders("root.hcl")
}

include "account" {
  path   = find_in_parent_folders("account.hcl")
  expose = true
}

terraform {
  source = "${get_repo_root()}//infrastructure/catalog/stacks/talos-cluster"
}

dependency "cloudstack_homecloud" {
  config_path = "../cloudstack-homecloud"

  mock_outputs = {
    zone_id              = "mock-zone-id"
    vpc_id               = "mock-vpc-id"
    iso_net_id           = "mock-net-id"
    talos_template_id    = "mock-template-id"
    keypair_name         = "nulcell"
    compute_offering_ids = {
      "mem.medium" = "mock-offering-id"
    }
  }
  mock_outputs_allowed_terraform_commands = ["validate", "plan"]
}

dependency "tailscale_vpn" {
  config_path = "../tailscale-vpn"

  mock_outputs = {
    router_vm_id = "mock-router-id"
  }
  mock_outputs_allowed_terraform_commands = ["validate", "plan"]
}

inputs = {
  cloudstack_api_url = include.account.locals.cloudstack_api_url
  op_vault           = include.account.locals.op_vault
  cluster_name       = include.account.locals.ops_cluster_name

  # Network: iso-net-shared isolated network (its own virtual router + public IP)
  zone_id    = dependency.cloudstack_homecloud.outputs.zone_id
  network_id = dependency.cloudstack_homecloud.outputs.iso_net_id
  vpc_id     = ""   # no VPC — isolated network

  talos_template_id = dependency.cloudstack_homecloud.outputs.talos_template_id
  keypair_name      = dependency.cloudstack_homecloud.outputs.keypair_name

  # Control plane: 1 node × mem.medium (2vCPU, 4GiB, 30GB)
  control_plane_count       = 1
  control_plane_offering_id = dependency.cloudstack_homecloud.outputs.compute_offering_ids["mem.medium"]
  control_plane_disk_size   = 30

  # Workers: 2 nodes × mem.medium
  worker_count       = 2
  worker_offering_id = dependency.cloudstack_homecloud.outputs.compute_offering_ids["mem.medium"]
  worker_disk_size   = 30

  kubernetes_version = "1.32.0"
  talos_version      = "v1.12.6"

  # ArgoCD on ops cluster — manages both clusters via GitOps
  enable_argocd       = true
  enable_cert_manager = false
  enable_external_dns = false
  enable_csi          = true
}
