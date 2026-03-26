# ---------------------------------------------------------------------------
# Ensure .kube directory exists before writing kubeconfig
# ---------------------------------------------------------------------------
resource "null_resource" "mkdir_kube" {
  triggers = {
    path = "${path.root}/.kube"
  }

  provisioner "local-exec" {
    command = "mkdir -p '${path.root}/.kube'"
  }
}

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

  timeouts {
    read = "15m"
  }
}

# ---------------------------------------------------------------------------
# Step 3 – Retrieve kubeconfig
# ---------------------------------------------------------------------------
data "talos_cluster_kubeconfig" "this" {
  client_configuration = var.client_configuration
  node                 = var.controlplane_ips[0]
  endpoint             = var.controlplane_ips[0]

  depends_on = [data.talos_cluster_health.this]

  timeouts {
    read = "10m"
  }
}

# ---------------------------------------------------------------------------
# Step 4 – Write kubeconfig to disk
# path.root refers to the calling stack's root directory
# ---------------------------------------------------------------------------
resource "local_sensitive_file" "kubeconfig" {
  content         = data.talos_cluster_kubeconfig.this.kubeconfig_raw
  filename        = "${path.root}/.kube/${var.cluster_name}.kubeconfig"
  file_permission = "0600"

  depends_on = [null_resource.mkdir_kube]
}

# ---------------------------------------------------------------------------
# Step 5 – Cilium CNI (always installed)
# ---------------------------------------------------------------------------
resource "null_resource" "cilium" {
  triggers = {
    chart_version = var.cilium_version
    cluster_name  = var.cluster_name
  }

  provisioner "local-exec" {
    command = <<-EOT
      helm repo add cilium https://helm.cilium.io --force-update
      helm upgrade --install cilium cilium/cilium \
        --version "${var.cilium_version}" \
        --kubeconfig "${path.root}/.kube/${var.cluster_name}.kubeconfig" \
        --namespace kube-system \
        --set kubeProxyReplacement=true \
        --set ipam.mode=kubernetes \
        --set k8sServiceHost="${split(":", replace(var.cluster_endpoint, "https://", ""))[0]}" \
        --set k8sServicePort=6443 \
        --wait
    EOT
  }

  depends_on = [local_sensitive_file.kubeconfig]
}

# ---------------------------------------------------------------------------
# Step 6 – CloudStack Cloud Controller Manager (conditional)
# NOTE: Helm repo URL below is a placeholder; verify the actual repo at
#       https://github.com/cloudstack-go/cloudstack-cloud-controller-manager
# ---------------------------------------------------------------------------
resource "null_resource" "ccm" {
  count = var.enable_ccm ? 1 : 0

  triggers = {
    chart_version = var.ccm_version
    cluster_name  = var.cluster_name
  }

  provisioner "local-exec" {
    command = <<-EOT
      helm repo add cloudstack-ccm https://kubernetes.github.io/cloud-provider-cloudstack --force-update
      helm upgrade --install cloudstack-ccm cloudstack-ccm/cloudstack-cloud-controller-manager \
        --version "${var.ccm_version}" \
        --kubeconfig "${path.root}/.kube/${var.cluster_name}.kubeconfig" \
        --namespace kube-system \
        --set config.cloudStack.apiUrl="${var.cloudstack_api_url}" \
        --set config.cloudStack.apiKey="${var.cloudstack_api_key}" \
        --set config.cloudStack.secretKey="${var.cloudstack_secret_key}" \
        --set config.cloudStack.zone="${var.cloudstack_zone_name}" \
        --wait
    EOT
  }

  depends_on = [null_resource.cilium]
}

# ---------------------------------------------------------------------------
# Step 7 – CloudStack CSI Driver (conditional)
# NOTE: Helm repo URL below is a placeholder; verify the actual repo at
#       https://github.com/cloudstack-go/cloudstack-csi
# ---------------------------------------------------------------------------
resource "null_resource" "csi" {
  count = var.enable_csi ? 1 : 0

  triggers = {
    chart_version = var.csi_version
    cluster_name  = var.cluster_name
  }

  provisioner "local-exec" {
    command = <<-EOT
      helm repo add cloudstack-csi https://kubernetes.github.io/cloud-provider-cloudstack --force-update
      helm upgrade --install cloudstack-csi cloudstack-csi/cloudstack-csi \
        --version "${var.csi_version}" \
        --kubeconfig "${path.root}/.kube/${var.cluster_name}.kubeconfig" \
        --namespace kube-system \
        --set config.cloudStack.apiUrl="${var.cloudstack_api_url}" \
        --set config.cloudStack.apiKey="${var.cloudstack_api_key}" \
        --set config.cloudStack.secretKey="${var.cloudstack_secret_key}" \
        --set config.cloudStack.zone="${var.cloudstack_zone_name}" \
        --wait
    EOT
  }

  depends_on = [null_resource.ccm]
}

# ---------------------------------------------------------------------------
# Step 8 – ArgoCD (conditional)
# ---------------------------------------------------------------------------
resource "null_resource" "argocd" {
  count = var.enable_argocd ? 1 : 0

  triggers = {
    chart_version = var.argocd_version
    cluster_name  = var.cluster_name
  }

  provisioner "local-exec" {
    command = <<-EOT
      helm repo add argo-cd https://argoproj.github.io/argo-helm --force-update
      helm upgrade --install argocd argo-cd/argo-cd \
        --version "${var.argocd_version}" \
        --kubeconfig "${path.root}/.kube/${var.cluster_name}.kubeconfig" \
        --namespace argocd \
        --create-namespace \
        --wait
    EOT
  }

  depends_on = [null_resource.csi]
}

# ---------------------------------------------------------------------------
# Step 9 – cert-manager (conditional)
# ---------------------------------------------------------------------------
resource "null_resource" "cert_manager" {
  count = var.enable_cert_manager ? 1 : 0

  triggers = {
    chart_version = var.cert_manager_version
    cluster_name  = var.cluster_name
  }

  provisioner "local-exec" {
    command = <<-EOT
      helm repo add cert-manager https://charts.jetstack.io --force-update
      helm upgrade --install cert-manager cert-manager/cert-manager \
        --version "${var.cert_manager_version}" \
        --kubeconfig "${path.root}/.kube/${var.cluster_name}.kubeconfig" \
        --namespace cert-manager \
        --create-namespace \
        --set crds.enabled=true \
        --wait
    EOT
  }

  depends_on = [null_resource.argocd]
}

# ---------------------------------------------------------------------------
# Step 10 – external-dns (conditional)
# ---------------------------------------------------------------------------
resource "null_resource" "external_dns" {
  count = var.enable_external_dns ? 1 : 0

  triggers = {
    chart_version = var.external_dns_version
    cluster_name  = var.cluster_name
  }

  provisioner "local-exec" {
    command = <<-EOT
      helm repo add external-dns https://kubernetes-sigs.github.io/external-dns/ --force-update
      helm upgrade --install external-dns external-dns/external-dns \
        --version "${var.external_dns_version}" \
        --kubeconfig "${path.root}/.kube/${var.cluster_name}.kubeconfig" \
        --namespace external-dns \
        --create-namespace \
        --set provider.name=cloudflare \
        --set "env[0].name=CF_API_TOKEN" \
        --set "env[0].value=${var.cloudflare_api_token}" \
        --wait
    EOT
  }

  depends_on = [null_resource.cert_manager]
}
