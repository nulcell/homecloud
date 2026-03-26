# workload-cluster unit
# Deploys the Talos Linux workload Kubernetes cluster on pub-net-1 (VPC public-lb subnet).
#
# This cluster hosts all user workloads: media server (ArgoCD Helm chart), n8n,
# Traefik ingress, and any other user-facing applications.
#
# Bootstrap flow:
#   1. Acquire CloudStack public IP (kube-apiserver LB endpoint)
#   2. Create LB rule port 6443 on that IP
#   3. Generate Talos machine secrets + controlplane/worker configs (endpoint = LB IP)
#   4. Deploy Talos VMs with machine config as base64 user_data
#   5. Assign control-plane VMs to LB rule
#   6. Bootstrap etcd via talos provider
#   7. Install Cilium CNI + CloudStack CCM + CSI + cert-manager + external-dns
#   8. Register cluster with ArgoCD running on ops cluster
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
    pub_net_1_id         = "mock-net-id"
    talos_template_id    = "mock-template-id"
    keypair_name         = "nulcell"
    compute_offering_ids = {
      "mem.medium"  = "mock-offering-id"
      "gen.1xlarge" = "mock-offering-id"
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

dependency "ops_cluster" {
  config_path = "../ops-cluster"

  mock_outputs = {
    argocd_server_url = "https://argocd.mock"
    kubeconfig        = "mock-kubeconfig"
  }
  mock_outputs_allowed_terraform_commands = ["validate", "plan"]
}

inputs = {
  cloudstack_api_url = include.account.locals.cloudstack_api_url
  op_vault           = include.account.locals.op_vault
  cluster_name       = include.account.locals.workload_cluster_name

  # Network: pub-net-1 (VPC public-lb subnet) for CloudStack LB rule support
  zone_id    = dependency.cloudstack_homecloud.outputs.zone_id
  network_id = dependency.cloudstack_homecloud.outputs.pub_net_1_id
  vpc_id     = dependency.cloudstack_homecloud.outputs.vpc_id

  talos_template_id = dependency.cloudstack_homecloud.outputs.talos_template_id
  keypair_name      = dependency.cloudstack_homecloud.outputs.keypair_name

  # Control plane: 1 node × mem.medium (2vCPU, 4GiB, 30GB)
  control_plane_count       = 1
  control_plane_offering_id = dependency.cloudstack_homecloud.outputs.compute_offering_ids["mem.medium"]
  control_plane_disk_size   = 30

  # Workers: 3 nodes × gen.1xlarge (12vCPU, 12GiB, 60GB)
  worker_count       = 3
  worker_offering_id = dependency.cloudstack_homecloud.outputs.compute_offering_ids["gen.1xlarge"]
  worker_disk_size   = 50

  kubernetes_version = "1.32.0"
  talos_version      = "v1.12.6"

  # Workload cluster add-ons
  enable_argocd       = false  # ArgoCD runs on ops cluster only
  enable_cert_manager = true
  enable_external_dns = true
  enable_csi          = true

  # external-dns: Cloudflare integration for DNS record management
  cloudflare_zone = include.account.locals.cloudflare_zone

  # ArgoCD registration — ops cluster kubeconfig used to register this cluster
  argocd_server_url  = dependency.ops_cluster.outputs.argocd_server_url
  ops_kubeconfig     = dependency.ops_cluster.outputs.kubeconfig
}
