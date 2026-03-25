# workload-cluster unit
# Deploys the Talos Linux workload Kubernetes cluster:
#   Bootstrap flow (per Talos v1.12 CloudStack docs):
#   1. Acquire CloudStack public IP for kube-apiserver LB endpoint
#   2. Create CloudStack LB rule (k8s-api, port 6443) on that IP
#   3. Generate Talos machine secrets + configs with endpoint = https://<LB_IP>:6443
#   4. Deploy Talos VMs with machine config as base64 user_data
#   5. Assign control plane VMs to LB rule
#   6. Bootstrap etcd, install Cilium + CloudStack CCM + CSI + external-dns
#   7. Register cluster with ArgoCD on ops cluster
#   8. Write talosconfig + kubeconfig to 1Password

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
    router_vm_id = "mock-router-id"
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

  # CloudStack placement — workload cluster runs in pub-net-1 (VPC, public-lb offering)
  # pub-net-1 is the only VPC public-lb subnet; the ops cluster uses iso-net-shared instead.
  zone_id             = dependency.cloudstack_homecloud.outputs.zone_id
  network_id          = dependency.cloudstack_homecloud.outputs.pub_net_1_id
  template_id         = dependency.cloudstack_homecloud.outputs.talos_template_id
  keypair_name        = dependency.cloudstack_homecloud.outputs.keypair_name
  compute_offering_id = dependency.cloudstack_homecloud.outputs.mem_medium_offering_id

  # Cluster topology
  controlplane_count = 1
  worker_count       = 3

  # kube-apiserver endpoint: a CloudStack public IP is acquired and fronted
  # by a CloudStack LB rule (port 6443). Machine config is generated with this
  # IP as the endpoint, then passed as base64 user_data to each VM.

  # Workload-cluster-specific add-ons
  enable_cloudstack_ccm = true
  enable_cloudstack_csi = true
  enable_external_dns   = true
  enable_cert_manager   = true
  cloudflare_zone       = include.account.locals.cloudflare_zone

  # ArgoCD registration — ops cluster will manage this cluster
  argocd_server_url = dependency.ops_cluster.outputs.argocd_server_url

  # 1Password — where to write generated secrets
  op_vault = include.account.locals.op_vault
}
