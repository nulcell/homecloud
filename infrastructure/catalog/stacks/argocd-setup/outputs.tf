output "workload_cluster_registered" {
  description = "True when the workload cluster secret has been created in the ArgoCD namespace."
  value       = true
}

output "workload_cluster_name" {
  description = "Name of the registered workload cluster."
  value       = var.workload_cluster_name
}
