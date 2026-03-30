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
# Step 6 – cloudstack-secret for CCM and CSI
# Uses the cloud-config INI format expected by both the CloudStack Kubernetes
# Provider (CCM) and the CloudStack CSI driver. Only created when either
# enable_ccm or enable_csi is true.
# ---------------------------------------------------------------------------
resource "null_resource" "cloudstack_secret" {
  count = (var.enable_ccm || var.enable_csi) ? 1 : 0

  triggers = {
    api_url  = var.cloudstack_api_url
    zone     = var.cloudstack_zone_name
    # Trigger re-create when credentials rotate (use hashed value, not raw).
    api_key_hash = sha256(var.cloudstack_api_key)
    secret_hash  = sha256(var.cloudstack_secret_key)
  }

  provisioner "local-exec" {
    command = <<-EOT
      kubectl --kubeconfig='${local_sensitive_file.kubeconfig.filename}' \
        -n kube-system create secret generic cloudstack-secret \
        --from-literal=cloud-config="[Global]
api-url = ${var.cloudstack_api_url}
api-key = ${var.cloudstack_api_key}
secret-key = ${var.cloudstack_secret_key}
zone = ${var.cloudstack_zone_name}
ssl-no-verify = false" \
        --dry-run=client -o yaml \
        | kubectl --kubeconfig='${local_sensitive_file.kubeconfig.filename}' apply -f -
    EOT
  }

  depends_on = [helm_release.cilium]
}

# ---------------------------------------------------------------------------
# Step 7 – CloudStack Cloud Controller Manager (conditional)
# Deployed as a manifest from the apache/cloudstack-kubernetes-provider repo.
# ---------------------------------------------------------------------------
resource "null_resource" "ccm" {
  count = var.enable_ccm ? 1 : 0

  triggers = {
    manifest_url = var.ccm_manifest_url
  }

  provisioner "local-exec" {
    command = "kubectl --kubeconfig='${local_sensitive_file.kubeconfig.filename}' apply -f '${var.ccm_manifest_url}'"
  }

  depends_on = [null_resource.cloudstack_secret]
}

# ---------------------------------------------------------------------------
# Step 8 – CloudStack CSI Driver (conditional)
# Snapshot CRDs must be applied before the main manifest. The upstream manifest
# contains a known typo ("rbac.authorization.k8s.io---") that requires a sed fix.
# ---------------------------------------------------------------------------
resource "null_resource" "csi_snapshot_crds" {
  count = var.enable_csi ? 1 : 0

  triggers = {
    manifest_url = var.csi_snapshot_crds_url
  }

  provisioner "local-exec" {
    command = "kubectl --kubeconfig='${local_sensitive_file.kubeconfig.filename}' apply -f '${var.csi_snapshot_crds_url}'"
  }

  depends_on = [null_resource.cloudstack_secret]
}

resource "null_resource" "csi" {
  count = var.enable_csi ? 1 : 0

  triggers = {
    manifest_url = var.csi_manifest_url
  }

  provisioner "local-exec" {
    command = <<-EOT
      TMP=$(mktemp)
      curl -fsSL '${var.csi_manifest_url}' \
        | sed 's/rbac.authorization.k8s.io---/rbac.authorization.k8s.io\n---/g' \
        > "$TMP"
      kubectl --kubeconfig='${local_sensitive_file.kubeconfig.filename}' apply -f "$TMP"
      rm -f "$TMP"
    EOT
  }

  depends_on = [null_resource.csi_snapshot_crds]
}

# ---------------------------------------------------------------------------
# Step 9 – ArgoCD (conditional)
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

  depends_on = [null_resource.csi, null_resource.ccm]
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
