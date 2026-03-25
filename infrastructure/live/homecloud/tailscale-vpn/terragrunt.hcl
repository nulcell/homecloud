# tailscale-vpn unit
# Deploys the Tailscale subnet router VM (homecloud-vpn-router):
#   - Ubuntu 24.04 VM connected to ALL CloudStack networks
#     (pub-net-1, priv-net-1, priv-net-2, priv-net-3, iso-net-shared)
#   - Cloud-init: cloudstack/compute/cloud-init/tailscale-router-debian.yaml
#     (registered as CloudStack user-data with params: tailscale_auth_key, network_router_cidr)
#   - Advertises route 10.0.0.0/15 into Tailscale tailnet (covers VPC + isolated net)
#   - Allows operators on the tailnet to reach all CloudStack private networks
#   - NOT involved in k8s inter-node traffic — Talos nodes use CloudStack VPC IPs directly

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

dependency "cloudstack_homecloud" {
  config_path = "../cloudstack-homecloud"

  mock_outputs = {
    zone_id             = "mock-zone-id"
    pub_net_1_id        = "mock-net-id"
    priv_net_1_id       = "mock-net-id"
    priv_net_2_id       = "mock-net-id"
    priv_net_3_id       = "mock-net-id"
    iso_net_id          = "mock-net-id"
    ubuntu_template_id  = "mock-template-id"
    tiny_offering_id    = "mock-offering-id"
    keypair_name        = "homecloud-key"
    tailscale_userdata_id = "mock-userdata-id"
  }
  mock_outputs_allowed_terraform_commands = ["validate", "plan"]
}

inputs = {
  # CloudStack placement
  zone_id             = dependency.cloudstack_homecloud.outputs.zone_id
  # VM is connected to all networks to route traffic between tailnet and all CloudStack subnets
  network_ids = [
    dependency.cloudstack_homecloud.outputs.pub_net_1_id,
    dependency.cloudstack_homecloud.outputs.priv_net_1_id,
    dependency.cloudstack_homecloud.outputs.priv_net_2_id,
    dependency.cloudstack_homecloud.outputs.priv_net_3_id,
    dependency.cloudstack_homecloud.outputs.iso_net_id,
  ]
  template_id         = dependency.cloudstack_homecloud.outputs.ubuntu_template_id
  compute_offering_id = dependency.cloudstack_homecloud.outputs.tiny_offering_id
  keypair_name        = dependency.cloudstack_homecloud.outputs.keypair_name
  userdata_id         = dependency.cloudstack_homecloud.outputs.tailscale_userdata_id

  # Tailscale auth key read from 1Password
  op_vault            = include.account.locals.op_vault
  op_tailscale_ref    = "op://homecloud/Tailscale Token/credential"

  # Advertised route covers VPC (10.0.0.0/24) + isolated net (10.1.1.0/24) = 10.0.0.0/15
  vpn_cidr            = "10.0.0.0/15"

  vm_name             = "homecloud-vpn-router"
  root_disk_size_gb   = 10
}
