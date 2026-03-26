output "kubeconfig" {
  description = "Raw kubeconfig YAML."
  value       = data.talos_cluster_kubeconfig.this.kubeconfig_raw
  sensitive   = true
}

output "kubeconfig_path" {
  description = "Local path where kubeconfig was written."
  value       = local_sensitive_file.kubeconfig.filename
}

output "cluster_ca" {
  description = "Kubernetes cluster CA certificate (base64)."
  value       = data.talos_cluster_kubeconfig.this.kubernetes_client_configuration.ca_certificate
}

output "client_cert" {
  description = "Kubernetes admin client certificate (base64)."
  value       = data.talos_cluster_kubeconfig.this.kubernetes_client_configuration.client_certificate
  sensitive   = true
}

output "client_key" {
  description = "Kubernetes admin client key (base64)."
  value       = data.talos_cluster_kubeconfig.this.kubernetes_client_configuration.client_key
  sensitive   = true
}

output "endpoint" {
  description = "Kubernetes API server endpoint."
  value       = var.cluster_endpoint
}
