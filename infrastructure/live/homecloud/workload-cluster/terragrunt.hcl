# workload-cluster unit
# Deploys the Talos Linux workload Kubernetes cluster:
#   - Talos machine config (controlplane + workers) with Tailscale extension
#   - CloudStack VMs (Talos ISO)
#   - Cluster bootstrap
#   - Cilium CNI (via Helm)
#   - CloudStack Cloud Controller Manager (CCM) — node lifecycle
#   - CloudStack CSI driver — PersistentVolume provisioning
#   - external-dns — Cloudflare DNS record management
#   - talosconfig + kubeconfig written to 1Password

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

dependency "cloudstack_platform" {
  config_path = "../cloudstack-platform"

  mock_outputs = {
    zone_id             = "mock-zone-id"
    vpc_id              = "mock-vpc-id"
    priv_net_2_id       = "mock-net-id"
    talos_template_id   = "mock-template-id"
    keypair_name        = "homecloud-key"
    compute_offering_id = "mock-offering-id"
  }
  mock_outputs_allowed_terraform_commands = ["validate", "plan"]
}

dependency "tailscale_vpn" {
  config_path = "../tailscale-vpn"

  mock_outputs = {
    workload_auth_key = "tskey-auth-mock"
  }
  mock_outputs_allowed_terraform_commands = ["validate", "plan"]
}

dependency "ops_cluster" {
  config_path = "../ops-cluster"

  mock_outputs = {
    argocd_server_url = "https://argocd.mock"
  }
  mock_outputs_allowed_terraform_commands = ["validate", "plan"]
}

inputs = {
  cluster_name = include.account.locals.workload_cluster_name
  is_ops       = false

  # CloudStack placement
  zone_id             = dependency.cloudstack_platform.outputs.zone_id
  vpc_id              = dependency.cloudstack_platform.outputs.vpc_id
  network_id          = dependency.cloudstack_platform.outputs.priv_net_2_id
  template_id         = dependency.cloudstack_platform.outputs.talos_template_id
  keypair_name        = dependency.cloudstack_platform.outputs.keypair_name
  compute_offering_id = dependency.cloudstack_platform.outputs.compute_offering_id

  # Cluster topology
  controlplane_count = 1
  worker_count       = 3

  # Tailscale extension config
  tailscale_auth_key = dependency.tailscale_vpn.outputs.workload_auth_key

  # Workload-cluster-specific add-ons
  enable_cloudstack_ccm = true
  enable_cloudstack_csi = true
  enable_external_dns   = true
  cloudflare_zone       = include.account.locals.cloudflare_zone

  # ArgoCD registration — ops cluster will manage this cluster
  argocd_server_url = dependency.ops_cluster.outputs.argocd_server_url

  # 1Password — where to write generated secrets
  op_vault = include.account.locals.op_vault
}
