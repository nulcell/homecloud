output "machine_secrets" {
  description = "Talos machine secrets object."
  value       = talos_machine_secrets.this.machine_secrets
  sensitive   = true
}

output "client_configuration" {
  description = "Talos client configuration object (ca, crt, key)."
  value       = talos_machine_secrets.this.client_configuration
  sensitive   = true
}

output "controlplane_config" {
  description = "Controlplane machine configuration YAML."
  value       = data.talos_machine_configuration.controlplane.machine_configuration
  sensitive   = true
}

output "worker_config" {
  description = "Worker machine configuration YAML."
  value       = data.talos_machine_configuration.worker.machine_configuration
  sensitive   = true
}

output "talosconfig" {
  description = "Talosconfig YAML (client config for talosctl)."
  value       = data.talos_client_configuration.this.talos_config
  sensitive   = true
}

output "controlplane_config_base64" {
  description = "Controlplane machine config encoded as base64 (for CloudStack user_data)."
  value       = base64encode(data.talos_machine_configuration.controlplane.machine_configuration)
  sensitive   = true
}

output "worker_config_base64" {
  description = "Worker machine config encoded as base64 (for CloudStack user_data)."
  value       = base64encode(data.talos_machine_configuration.worker.machine_configuration)
  sensitive   = true
}

output "cluster_endpoint" {
  description = "Kubernetes API server endpoint (https://<LB_IP>:6443)."
  value       = var.cluster_endpoint
}
