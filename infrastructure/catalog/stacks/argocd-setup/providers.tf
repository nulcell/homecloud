# ---------------------------------------------------------------------------
# Read ops cluster kubeconfig from 1Password
# ---------------------------------------------------------------------------
data "onepassword_item" "ops_kubeconfig" {
  vault = var.op_vault
  title = "Kubeconfig - ${var.ops_cluster_name}"
}

# ---------------------------------------------------------------------------
# Locals — extract kubeconfig YAML from the 1Password item
# ---------------------------------------------------------------------------
locals {
  _ops_kube_fields = flatten([for s in data.onepassword_item.ops_kubeconfig.section : s.field])
  ops_kubeconfig   = one([for f in local._ops_kube_fields : f.value if f.label == "config"])
  _ops_kube_parsed = yamldecode(local.ops_kubeconfig)
}

# ---------------------------------------------------------------------------
# Providers — kubernetes provider configured from ops cluster kubeconfig
# ---------------------------------------------------------------------------

provider "kubernetes" {
  host = local._ops_kube_parsed["clusters"][0]["cluster"]["server"]
  cluster_ca_certificate = base64decode(
    local._ops_kube_parsed["clusters"][0]["cluster"]["certificate-authority-data"]
  )
  client_certificate = base64decode(
    local._ops_kube_parsed["users"][0]["user"]["client-certificate-data"]
  )
  client_key = base64decode(
    local._ops_kube_parsed["users"][0]["user"]["client-key-data"]
  )
}

provider "onepassword" {
  # Authenticates via OP_SERVICE_ACCOUNT_TOKEN or an active op CLI session.
}
