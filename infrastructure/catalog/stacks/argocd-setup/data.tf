data "onepassword_item" "ops_kubeconfig" {
  vault = var.op_vault
  title = "Kubeconfig - ${var.ops_cluster_name}"
}
