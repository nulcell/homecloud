# tailscale-vpn — VPN subnet router VM connecting all 5 CloudStack networks

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
    pub_net_1_id  = "mock-pub-net-1-id"
    priv_net_1_id = "mock-priv-net-1-id"
    priv_net_2_id = "mock-priv-net-2-id"
    priv_net_3_id = "mock-priv-net-3-id"
    iso_net_id    = "mock-iso-net-id"
    keypair_name  = "nulcell"
    userdata_ids  = { "tailscale-router-debian" = "mock-userdata-id" }
  }
  mock_outputs_allowed_terraform_commands = ["validate", "plan"]
}

inputs = {
  is_enabled         = false
  cloudstack_api_url = include.account.locals.cloudstack_api_url
  op_vault           = include.account.locals.op_vault
  op_account         = include.account.locals.op_account
  zone_name          = include.account.locals.zone_name

  vm_name               = "homecloud-vpn-router"
  template_name         = "Ubuntu 24.04 - Noble"
  compute_offering_name = "acs.comp.gen.tiny"
  root_disk_size_gb     = 10
  keypair_name          = dependency.cloudstack_homecloud.outputs.keypair_name

  # Network NICs in attachment order (NIC0 is pub-net-1).
  # All 5 networks are attached so the router can reach every CloudStack segment.
  network_ids = [
    dependency.cloudstack_homecloud.outputs.pub_net_1_id,
    dependency.cloudstack_homecloud.outputs.priv_net_1_id,
    dependency.cloudstack_homecloud.outputs.priv_net_2_id,
    dependency.cloudstack_homecloud.outputs.priv_net_3_id,
    dependency.cloudstack_homecloud.outputs.iso_net_id,
  ]

  # Userdata script that bootstraps Tailscale on first boot.
  # Template substitution parameters: tailscale_auth_key, network_router_cidr.
  userdata_id = lookup(
    dependency.cloudstack_homecloud.outputs.userdata_ids,
    "tailscale-router-debian",
    "c48a7c09-4255-4881-9802-8cd9548c6114" # fallback to known ID on mock plan
  )

  # VPN CIDR advertised to tailnet — covers VPC (10.0.0.0/24) + isolated net (10.1.1.0/24).
  vpn_cidr = "10.0.0.0/15"

  # Set to a 1Password item title whose `password` field holds an existing Tailscale auth key.
  # Leave empty to generate a fresh ephemeral key via the Tailscale API.
  op_tailscale_ref = ""
}
