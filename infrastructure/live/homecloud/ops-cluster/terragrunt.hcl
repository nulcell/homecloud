# ops-cluster unit
# Deploys the Talos Linux ops Kubernetes cluster:
#   - Talos machine config (controlplane + workers)
#   - CloudStack VMs (Talos ISO) with Tailscale extension config injected
#   - Cluster bootstrap via talos provider
#   - Cilium CNI (via Helm)
#   - ArgoCD (via Helm) — manages workload cluster apps
#   - Core monitoring: Prometheus, Grafana, Loki, Alertmanager
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
    zone_id            = "mock-zone-id"
    vpc_id             = "mock-vpc-id"
    priv_net_1_id      = "mock-net-id"
    talos_template_id  = "mock-template-id"
    keypair_name       = "homecloud-key"
    compute_offering_id = "mock-offering-id"
  }
  mock_outputs_allowed_terraform_commands = ["validate", "plan"]
}

dependency "tailscale_vpn" {
  config_path = "../tailscale-vpn"

  mock_outputs = {
    ops_auth_key = "tskey-auth-mock"
  }
  mock_outputs_allowed_terraform_commands = ["validate", "plan"]
}

inputs = {
  cluster_name = include.account.locals.ops_cluster_name
  is_ops       = true

  # CloudStack placement
  zone_id             = dependency.cloudstack_platform.outputs.zone_id
  vpc_id              = dependency.cloudstack_platform.outputs.vpc_id
  network_id          = dependency.cloudstack_platform.outputs.priv_net_1_id
  template_id         = dependency.cloudstack_platform.outputs.talos_template_id
  keypair_name        = dependency.cloudstack_platform.outputs.keypair_name
  compute_offering_id = dependency.cloudstack_platform.outputs.compute_offering_id

  # Cluster topology
  controlplane_count = 1
  worker_count       = 2

  # Tailscale extension config (injected into Talos machine config)
  tailscale_auth_key = dependency.tailscale_vpn.outputs.ops_auth_key

  # ArgoCD bootstrap (ops cluster only)
  enable_argocd = true

  # 1Password — where to write generated secrets
  op_vault = include.account.locals.op_vault
}
