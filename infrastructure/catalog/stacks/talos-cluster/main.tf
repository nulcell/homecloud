# ---------------------------------------------------------------------------
# Step 1 – Allocate a public IP for the Kubernetes API LB
# vpc_id is only set for VPC-based clusters (workload); isolated-network
# clusters (ops) omit vpc_id and allocate a zone-level public IP.
# ---------------------------------------------------------------------------
resource "cloudstack_ipaddress" "lb" {
  count      = var.is_enabled ? 1 : 0
  vpc_id     = var.vpc_id != "" ? var.vpc_id : null
  network_id = var.network_id != "" && var.vpc_id == "" ? var.network_id : null
  zone       = var.zone_name
}

# ---------------------------------------------------------------------------
# Step 2 – Generate Talos machine secrets and render machine configs
# ---------------------------------------------------------------------------
module "talos_config" {
  count  = var.is_enabled ? 1 : 0
  source = "../../modules/talos-config"

  cluster_name         = var.cluster_name
  cluster_endpoint     = "https://${cloudstack_ipaddress.lb[0].ip_address}:6443"
  kubernetes_version   = var.kubernetes_version
  talos_version        = var.talos_version
  control_plane_count  = var.controlplane_count
  worker_count         = var.worker_count
  extra_config_patches = var.talos_config_patches
}

# ---------------------------------------------------------------------------
# Step 3 – Deploy control plane VMs
# ---------------------------------------------------------------------------
module "control_plane_vms" {
  count  = var.is_enabled ? var.controlplane_count : 0
  source = "../../modules/cloudstack-vm"

  name             = "${var.cluster_name}-cp-${count.index}"
  zone_name        = var.zone_name
  account_name     = var.account_name
  domain_id        = var.domain_id
  template_name    = var.template_name
  offering_name    = var.compute_offering_name
  root_disk_size   = var.control_plane_disk_size
  network_ids      = [var.network_id]
  keypair_name     = var.keypair_name
  user_data_base64 = module.talos_config[0].controlplane_config_base64
}

# ---------------------------------------------------------------------------
# Step 4 – Push machine config to control plane VMs via Talos maintenance API
# Talos may fail to resolve "data-server." (the CloudStack metadata DNS name)
# if the zone DNS is an external resolver that doesn't know this name. Pushing
# the config explicitly via port 50000 (maintenance mode) is more reliable and
# makes the config delivery deterministic regardless of DNS setup.
#
# Uses the LB public IP (exposed via the Talos API LB rule below) so that
# the Terraform runner does not need VPN access to the private VM IPs.
# ---------------------------------------------------------------------------
resource "cloudstack_loadbalancer_rule" "talos_api" {
  count         = var.is_enabled ? 1 : 0
  name          = "${var.cluster_name}-talos-api"
  ip_address_id = cloudstack_ipaddress.lb[0].id
  network_id    = var.network_id != "" ? var.network_id : null
  algorithm     = "leastconn"
  private_port  = 50000
  public_port   = 50000
  protocol      = "tcp"
  member_ids    = [for vm in module.control_plane_vms : vm.vm_id]
  cidrlist      = ["0.0.0.0/0"]

  depends_on = [module.control_plane_vms]
}

resource "talos_machine_configuration_apply" "controlplane" {
  count = var.is_enabled ? var.controlplane_count : 0

  client_configuration        = module.talos_config[0].client_configuration
  machine_configuration_input = module.talos_config[0].controlplane_config
  # endpoint and node both use the LB IP — the Terraform runner cannot reach
  # private VM IPs directly; the LB forwards port 50000 to the control plane VM.
  node     = cloudstack_ipaddress.lb[0].ip_address
  endpoint = cloudstack_ipaddress.lb[0].ip_address

  depends_on = [cloudstack_loadbalancer_rule.talos_api]
}

# ---------------------------------------------------------------------------
# Step 5 – Create LB rule for the Kubernetes API server (port 6443)
# ---------------------------------------------------------------------------
resource "cloudstack_loadbalancer_rule" "apiserver" {
  count         = var.is_enabled ? 1 : 0
  name          = "${var.cluster_name}-apiserver"
  ip_address_id = cloudstack_ipaddress.lb[0].id
  network_id    = var.network_id != "" ? var.network_id : null
  algorithm     = "roundrobin"
  private_port  = 6443
  public_port   = 6443
  protocol      = "tcp"
  member_ids    = [for vm in module.control_plane_vms : vm.vm_id]
  cidrlist      = ["0.0.0.0/0"] # allow API access from anywhere (can be restricted if desired)

  depends_on = [talos_machine_configuration_apply.controlplane]
}

# ---------------------------------------------------------------------------
# Step 6 – Bootstrap cluster and install Helm charts
# Depends on LB rule so that the API endpoint is reachable before bootstrap
# ---------------------------------------------------------------------------
module "bootstrap" {
  count  = var.is_enabled ? 1 : 0
  source = "../../modules/kubernetes-bootstrap"

  providers = {
    helm = helm.cluster
  }

  cluster_name         = var.cluster_name
  cluster_endpoint     = "https://${cloudstack_ipaddress.lb[0].ip_address}:6443"
  talos_endpoint       = cloudstack_ipaddress.lb[0].ip_address
  client_configuration = module.talos_config[0].client_configuration
  controlplane_ips     = [for vm in module.control_plane_vms : vm.private_ip]

  enable_argocd       = var.enable_argocd
  enable_cert_manager = var.enable_cert_manager
  enable_external_dns = var.enable_external_dns
  enable_csi          = var.enable_cloudstack_csi
  enable_ccm          = var.enable_cloudstack_ccm

  cilium_version        = var.cilium_version
  ccm_manifest_url      = var.ccm_manifest_url
  csi_snapshot_crds_url = var.csi_snapshot_crds_url
  csi_manifest_url      = var.csi_manifest_url
  argocd_version        = var.argocd_version
  cert_manager_version  = var.cert_manager_version
  external_dns_version  = var.external_dns_version

  cloudstack_api_url    = var.cloudstack_api_url
  cloudstack_api_key    = local.cs_api_key
  cloudstack_secret_key = local.cs_secret_key
  cloudstack_zone_name  = var.zone_name

  depends_on = [cloudstack_loadbalancer_rule.apiserver]
}

# ---------------------------------------------------------------------------
# Step 7 – Deploy worker VMs (after bootstrap so kubelet can join immediately)
# ---------------------------------------------------------------------------
module "worker_vms" {
  count  = var.is_enabled ? var.worker_count : 0
  source = "../../modules/cloudstack-vm"

  name             = "${var.cluster_name}-worker-${count.index}"
  zone_name        = var.zone_name
  account_name     = var.account_name
  domain_id        = var.domain_id
  template_name    = var.template_name
  offering_name    = var.compute_offering_name
  root_disk_size   = var.worker_disk_size
  network_ids      = [var.network_id]
  keypair_name     = var.keypair_name
  user_data_base64 = module.talos_config[0].worker_config_base64

  depends_on = [module.bootstrap]
}

# ---------------------------------------------------------------------------
# Step 8 – Push machine config to worker VMs
# Same pattern as controlplane: explicit push avoids reliance on data-server.
# ---------------------------------------------------------------------------
# ---------------------------------------------------------------------------
# Step 8 – Push machine config to worker VMs
# Workers need port 50000 exposed. We add a dedicated LB rule (workers get
# their own public IP, or we reuse the same LB IP with a separate rule).
# Worker config apply uses the same LB IP as the control plane — the LB
# round-robins across all members, but since each worker's config is
# identical (same worker config YAML), any delivery succeeds.
# Workers are added to the Talos API LB rule to make port 50000 reachable.
# ---------------------------------------------------------------------------
resource "cloudstack_loadbalancer_rule" "talos_api_workers" {
  count         = var.is_enabled && var.worker_count > 0 ? 1 : 0
  name          = "${var.cluster_name}-talos-api-workers"
  ip_address_id = cloudstack_ipaddress.lb[0].id
  network_id    = var.network_id != "" ? var.network_id : null
  algorithm     = "roundrobin"
  private_port  = 50000
  public_port   = 50001
  protocol      = "tcp"
  member_ids    = [for vm in module.worker_vms : vm.vm_id]
  cidrlist      = ["0.0.0.0/0"]

  depends_on = [module.worker_vms]
}

resource "talos_machine_configuration_apply" "worker" {
  count = var.is_enabled && var.worker_count > 0 ? 1 : 0

  client_configuration        = module.talos_config[0].client_configuration
  machine_configuration_input = module.talos_config[0].worker_config
  # Connect via LB port 50001 → worker VMs port 50000
  node     = cloudstack_ipaddress.lb[0].ip_address
  endpoint = "${cloudstack_ipaddress.lb[0].ip_address}:50001"

  depends_on = [cloudstack_loadbalancer_rule.talos_api_workers]
}

# ---------------------------------------------------------------------------
# Step 9 – Store talosconfig and kubeconfig in 1Password
# ---------------------------------------------------------------------------
module "op_talosconfig" {
  count  = var.is_enabled ? 1 : 0
  source = "../../modules/onepassword-item"

  vault    = var.op_vault
  title    = "Talosconfig - ${var.cluster_name}"
  category = "secure_note"
  fields = {
    config = module.talos_config[0].talosconfig
  }
}

module "op_kubeconfig" {
  count  = var.is_enabled ? 1 : 0
  source = "../../modules/onepassword-item"

  vault    = var.op_vault
  title    = "Kubeconfig - ${var.cluster_name}"
  category = "secure_note"
  fields = {
    config = module.bootstrap[0].kubeconfig
  }
}
