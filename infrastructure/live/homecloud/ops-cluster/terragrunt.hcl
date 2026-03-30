# ops cluster — Talos Linux on iso-net-shared

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
    zone_id      = "mock-zone-id"
    iso_net_id   = "mock-net-id"
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

inputs = {
  is_enabled         = false
  cloudstack_api_url = include.account.locals.cloudstack_api_url
  op_vault           = include.account.locals.op_vault
  op_account         = include.account.locals.op_account
  cluster_name       = include.account.locals.ops_cluster_name

  # Network: iso-net-shared isolated network (its own virtual router + public IP)
  network_id = dependency.cloudstack_homecloud.outputs.iso_net_id
  vpc_id     = ""   # no VPC — isolated network

  template_name         = "Talos v1.12.6 - CloudStack"
  compute_offering_name = "mem.medium"
  keypair_name          = dependency.cloudstack_homecloud.outputs.keypair_name

  # Control plane: 1 node, workers: 2 nodes
  controlplane_count      = 1
  control_plane_disk_size = 30
  worker_count            = 2
  worker_disk_size        = 30

  kubernetes_version = "1.32.0"
  talos_version      = "v1.12.6"

  # ArgoCD on ops cluster — manages both clusters via GitOps
  enable_argocd         = true
  enable_cloudstack_ccm = true
  enable_cloudstack_csi = true
  enable_cert_manager   = false
  enable_external_dns   = false
}
