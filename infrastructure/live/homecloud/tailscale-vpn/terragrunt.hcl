# tailscale-vpn unit
# Deploys Tailscale tailnet configuration:
#   - Auth keys (reusable, tagged) for ops and workload cluster nodes
#   - ACL policy (node-to-node within VPC CIDR)
#   - MagicDNS / split-DNS for homecloud.internal

include "root" {
  path = find_in_parent_folders("root.hcl")
}

include "account" {
  path   = find_in_parent_folders("account.hcl")
  expose = true
}

terraform {
  source = "${get_repo_root()}//infrastructure/catalog/stacks/tailscale-vpn"
}

dependency "cloudstack_platform" {
  config_path = "../cloudstack-platform"

  mock_outputs = {
    vpc_cidr = "10.0.0.0/24"
  }
  mock_outputs_allowed_terraform_commands = ["validate", "plan"]
}

inputs = {
  tailnet   = include.account.locals.tailscale_tailnet
  vpc_cidr  = dependency.cloudstack_platform.outputs.vpc_cidr

  # Reusable tagged auth keys written to 1Password after creation
  auth_keys = {
    ops_nodes      = { tags = ["tag:ops-node"],      reusable = true, ephemeral = false }
    workload_nodes = { tags = ["tag:workload-node"], reusable = true, ephemeral = false }
    vps_node       = { tags = ["tag:vps"],           reusable = true, ephemeral = false }
  }

  op_vault = include.account.locals.op_vault
}
