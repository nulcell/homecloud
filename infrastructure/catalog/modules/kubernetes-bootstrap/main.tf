# ---------------------------------------------------------------------------
# Step 1 – Bootstrap etcd on the first control plane node
# lifecycle.ignore_changes = all prevents re-bootstrapping on subsequent applies
# ---------------------------------------------------------------------------
resource "talos_machine_bootstrap" "this" {
  node                 = var.controlplane_ips[0]
  endpoint             = var.controlplane_ips[0]
  client_configuration = var.client_configuration

  lifecycle {
    ignore_changes = all
  }
}

# ---------------------------------------------------------------------------
# Step 2 – Wait for cluster health before proceeding
# ---------------------------------------------------------------------------
data "talos_cluster_health" "this" {
  client_configuration = var.client_configuration
  control_plane_nodes  = var.controlplane_ips
  worker_nodes         = var.worker_ips
  endpoints            = [replace(var.cluster_endpoint, "https://", "")]

  depends_on = [talos_machine_bootstrap.this]

  timeouts = { read = "15m" }
}

# ---------------------------------------------------------------------------
# Step 3 – Retrieve kubeconfig
# ---------------------------------------------------------------------------
resource "talos_cluster_kubeconfig" "this" {
  client_configuration = var.client_configuration
  node                 = var.controlplane_ips[0]
  endpoint             = var.controlplane_ips[0]

  depends_on = [data.talos_cluster_health.this]

  timeouts = { read = "10m" }
}

# ---------------------------------------------------------------------------
# Step 4 – Write kubeconfig to disk
# The calling stack's helm provider uses config_path pointing to this file.
# NOTE: On first cluster setup two applies are needed — the first bootstraps
#       the cluster and writes the kubeconfig; the second runs the helm
#       releases (which require the kubeconfig file to already exist so that
#       the helm provider can initialise at plan time).
# ---------------------------------------------------------------------------
resource "local_sensitive_file" "kubeconfig" {
  content              = resource.talos_cluster_kubeconfig.this.kubeconfig_raw
  filename             = "${path.root}/.kube/${var.cluster_name}.kubeconfig"
  file_permission      = "0600"
  directory_permission = "0700"
}

# ---------------------------------------------------------------------------
# Step 5 – Cilium CNI (always installed)
# helm.cluster is configured in the calling stack — see providers.tf there.
# ---------------------------------------------------------------------------
resource "helm_release" "cilium" {

  name       = "cilium"
  repository = "https://helm.cilium.io"
  chart      = "cilium"
  version    = var.cilium_version
  namespace  = "kube-system"
  wait       = true
  timeout    = 600

  set = [
    { name = "kubeProxyReplacement", value = "true" },
    { name = "ipam.mode", value = "kubernetes" },
    { name = "k8sServiceHost", value = split(":", replace(var.cluster_endpoint, "https://", ""))[0] },
    { name = "k8sServicePort", value = "6443" },
  ]

  depends_on = [local_sensitive_file.kubeconfig]
}

# ---------------------------------------------------------------------------
# Step 6 – CloudStack Cloud Controller Manager (conditional)
# ---------------------------------------------------------------------------
resource "helm_release" "ccm" {
  count    = var.enable_ccm ? 1 : 0

  name       = "cloudstack-ccm"
  repository = "https://kubernetes.github.io/cloud-provider-cloudstack"
  chart      = "cloudstack-cloud-controller-manager"
  version    = var.ccm_version
  namespace  = "kube-system"
  wait       = true
  timeout    = 300

  set = [
    { name = "config.cloudStack.apiUrl", value = var.cloudstack_api_url },
    { name = "config.cloudStack.zone", value = var.cloudstack_zone_name },
  ]
  set_sensitive = [
    { name = "config.cloudStack.apiKey", value = var.cloudstack_api_key },
    { name = "config.cloudStack.secretKey", value = var.cloudstack_secret_key },
  ]

  depends_on = [helm_release.cilium]
}

# ---------------------------------------------------------------------------
# Step 7 – CloudStack CSI Driver (conditional)
# ---------------------------------------------------------------------------
resource "helm_release" "csi" {
  count    = var.enable_csi ? 1 : 0

  name       = "cloudstack-csi"
  repository = "https://kubernetes.github.io/cloud-provider-cloudstack"
  chart      = "cloudstack-csi"
  version    = var.csi_version
  namespace  = "kube-system"
  wait       = true
  timeout    = 300

  set = [
    { name = "config.cloudStack.apiUrl", value = var.cloudstack_api_url },
    { name = "config.cloudStack.zone", value = var.cloudstack_zone_name },
  ]
  set_sensitive = [
    { name = "config.cloudStack.apiKey", value = var.cloudstack_api_key },
    { name = "config.cloudStack.secretKey", value = var.cloudstack_secret_key },
  ]

  depends_on = [helm_release.ccm]
}

# ---------------------------------------------------------------------------
# Step 8 – ArgoCD (conditional)
# ---------------------------------------------------------------------------
resource "helm_release" "argocd" {
  count    = var.enable_argocd ? 1 : 0

  name             = "argocd"
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  version          = var.argocd_version
  namespace        = "argocd"
  create_namespace = true
  wait             = true
  timeout          = 600

  depends_on = [helm_release.csi]
}

# ---------------------------------------------------------------------------
# Step 9 – cert-manager (conditional)
# ---------------------------------------------------------------------------
resource "helm_release" "cert_manager" {
  count    = var.enable_cert_manager ? 1 : 0

  name             = "cert-manager"
  repository       = "https://charts.jetstack.io"
  chart            = "cert-manager"
  version          = var.cert_manager_version
  namespace        = "cert-manager"
  create_namespace = true
  wait             = true
  timeout          = 300

  set = [
    { name = "crds.enabled", value = "true" },
  ]

  depends_on = [helm_release.argocd]
}

# ---------------------------------------------------------------------------
# Step 10 – external-dns (conditional)
# ---------------------------------------------------------------------------
resource "helm_release" "external_dns" {
  count    = var.enable_external_dns ? 1 : 0

  name             = "external-dns"
  repository       = "https://kubernetes-sigs.github.io/external-dns/"
  chart            = "external-dns"
  version          = var.external_dns_version
  namespace        = "external-dns"
  create_namespace = true
  wait             = true
  timeout          = 300

  set = [
    { name = "provider.name", value = "cloudflare" },
    { name = "env[0].name", value = "CF_API_TOKEN" },
  ]
  set_sensitive = [
    { name = "env[0].value", value = var.cloudflare_api_token },
  ]

  depends_on = [helm_release.cert_manager]
}
