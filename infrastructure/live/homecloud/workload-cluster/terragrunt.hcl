# workload cluster — Talos Linux on pub-net-1 (VPC public-lb subnet)

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
    vpc_id       = "mock-vpc-id"
    pub_net_1_id = "mock-net-id"
    keypair_name = "nulcell"
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
  is_enabled         = false
  cloudstack_api_url = include.account.locals.cloudstack_api_url
  op_vault           = include.account.locals.op_vault
  op_account         = include.account.locals.op_account
  cluster_name       = include.account.locals.workload_cluster_name

  # Network: pub-net-1 (VPC public-lb subnet) for CloudStack LB rule support
  network_id = dependency.cloudstack_homecloud.outputs.pub_net_1_id
  vpc_id     = dependency.cloudstack_homecloud.outputs.vpc_id

  template_name         = "Talos v1.12.6 - CloudStack"
  compute_offering_name = "mem.medium"
  keypair_name          = dependency.cloudstack_homecloud.outputs.keypair_name

  # Control plane: 1 node, workers: 3 nodes (gen.1xlarge)
  controlplane_count      = 1
  control_plane_disk_size = 30
  worker_count            = 3
  worker_disk_size        = 50

  kubernetes_version = "1.32.0"
  talos_version      = "v1.12.6"

  # Workload cluster add-ons
  enable_argocd         = false  # ArgoCD runs on ops cluster only
  enable_cloudstack_ccm = true
  enable_cloudstack_csi = true
  enable_cert_manager   = true
  enable_external_dns   = true

  cloudflare_zone = include.account.locals.cloudflare_zone

  argocd_server_url = dependency.ops_cluster.outputs.argocd_server_url
}
