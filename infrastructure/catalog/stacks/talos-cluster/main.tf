# ---------------------------------------------------------------------------
# Step 1 – Allocate a public IP for the Kubernetes API LB
# vpc_id is only set for VPC-based clusters (workload); isolated-network
# clusters (ops) omit vpc_id and allocate a zone-level public IP.
# ---------------------------------------------------------------------------
resource "cloudstack_ipaddress" "lb" {
  vpc_id = var.vpc_id != "" ? var.vpc_id : null
  zone   = var.zone_name
}

# ---------------------------------------------------------------------------
# Step 2 – Generate Talos machine secrets and render machine configs
# ---------------------------------------------------------------------------
module "talos_config" {
  source = "../../modules/talos-config"

  cluster_name         = var.cluster_name
  cluster_endpoint     = "https://${cloudstack_ipaddress.lb.ip_address}:6443"
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
  count  = var.controlplane_count
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
  user_data_base64 = module.talos_config.controlplane_config_base64
}

# ---------------------------------------------------------------------------
# Step 4 – Create LB rule on the public IP pointing to control plane VMs
# member_ids is set after VMs exist via depends_on
# ---------------------------------------------------------------------------
resource "cloudstack_loadbalancer_rule" "apiserver" {
  name          = "${var.cluster_name}-apiserver"
  ip_address_id = cloudstack_ipaddress.lb.id
  algorithm     = "roundrobin"
  private_port  = 6443
  public_port   = 6443
  protocol      = "tcp"
  member_ids    = [for vm in module.control_plane_vms : vm.vm_id]

  depends_on = [module.control_plane_vms]
}

# ---------------------------------------------------------------------------
# Step 5 – Bootstrap cluster and install Helm charts
# Depends on LB rule so that the API endpoint is reachable before bootstrap
# ---------------------------------------------------------------------------
module "bootstrap" {
  source = "../../modules/kubernetes-bootstrap"

  providers = {
    helm = helm.cluster
  }

  cluster_name         = var.cluster_name
  cluster_endpoint     = "https://${cloudstack_ipaddress.lb.ip_address}:6443"
  client_configuration = module.talos_config.client_configuration
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
# Step 6 – Deploy worker VMs (after bootstrap so kubelet can join immediately)
# ---------------------------------------------------------------------------
module "worker_vms" {
  count  = var.worker_count
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
  user_data_base64 = module.talos_config.worker_config_base64

  depends_on = [module.bootstrap]
}

# ---------------------------------------------------------------------------
# Step 7 – Store talosconfig in 1Password
# ---------------------------------------------------------------------------
module "op_talosconfig" {
  source = "../../modules/onepassword-item"

  vault = var.op_vault
  title = "Talosconfig - ${var.cluster_name}"
  fields = {
    config = module.talos_config.talosconfig
  }
}

# ---------------------------------------------------------------------------
# Step 8 – Store kubeconfig in 1Password
# ---------------------------------------------------------------------------
module "op_kubeconfig" {
  source = "../../modules/onepassword-item"

  vault = var.op_vault
  title = "Kubeconfig - ${var.cluster_name}"
  fields = {
    config = module.bootstrap.kubeconfig
  }
}
