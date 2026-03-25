# media-server unit
# Deploys optional media server components:
#   - SharedFileSystem: media-server-fs-config (NFS, 10 GB)
#   - SharedFileSystem: media-server-fs-data   (NFS, 500 GB)
#   - media-server VM (Ubuntu, joined to iso-net-shared)
# Set is_enabled = false to skip all resources without removing the unit.

include "root" {
  path = find_in_parent_folders("root.hcl")
}

include "account" {
  path   = find_in_parent_folders("account.hcl")
  expose = true
}

terraform {
  source = "${get_repo_root()}//infrastructure/catalog/stacks/media-server"
}

dependency "cloudstack_platform" {
  config_path = "../cloudstack-platform"

  mock_outputs = {
    zone_id              = "mock-zone-id"
    iso_net_id           = "mock-net-id"
    ubuntu_template_id   = "mock-template-id"
    keypair_name         = "homecloud-key"
    compute_offering_id  = "mock-offering-id"
    disk_offering_id     = "mock-disk-offering-id"
  }
  mock_outputs_allowed_terraform_commands = ["validate", "plan"]
}

inputs = {
  is_enabled = true # flip to false to tear down / skip

  zone_id             = dependency.cloudstack_platform.outputs.zone_id
  network_id          = dependency.cloudstack_platform.outputs.iso_net_id
  template_id         = dependency.cloudstack_platform.outputs.ubuntu_template_id
  keypair_name        = dependency.cloudstack_platform.outputs.keypair_name
  compute_offering_id = dependency.cloudstack_platform.outputs.compute_offering_id

  # Shared filesystem sizes
  fs_config_size_gb = 10
  fs_data_size_gb   = 500

  op_vault = include.account.locals.op_vault
}
