resource "kubernetes_secret" "workload_cluster" {
  metadata {
    name      = var.workload_cluster_name
    namespace = "argocd"
    labels = {
      "argocd.argoproj.io/secret-type" = "cluster"
    }
  }

  data = {
    name   = var.workload_cluster_name
    server = var.workload_cluster_endpoint
    config = jsonencode({
      tlsClientConfig = {
        caData   = var.workload_cluster_ca
        certData = var.workload_cluster_cert
        keyData  = var.workload_cluster_key
      }
    })
  }
}
