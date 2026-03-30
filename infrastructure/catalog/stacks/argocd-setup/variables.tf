variable "op_vault" {
  type        = string
  default     = "homecloud"
  description = "1Password vault name or UUID."
}

variable "op_account" {
  type        = string
  description = "1Password account URL (e.g. my.1password.com) for CLI-based provider auth."
}

variable "ops_cluster_name" {
  type        = string
  default     = "ops"
  description = "Name of the ops cluster (used to look up kubeconfig from 1Password)."
}

variable "workload_cluster_name" {
  type        = string
  description = "Name of the workload cluster to register in ArgoCD."
}

variable "workload_cluster_endpoint" {
  type        = string
  description = "Kubernetes API server URL for the workload cluster (https://<IP>:6443)."
}

variable "workload_cluster_ca" {
  type        = string
  description = "Base64-encoded cluster CA certificate for the workload cluster."
}

variable "workload_cluster_cert" {
  type        = string
  sensitive   = true
  description = "Base64-encoded client certificate for the workload cluster."
}

variable "workload_cluster_key" {
  type        = string
  sensitive   = true
  description = "Base64-encoded client key for the workload cluster."
}

variable "is_enabled" {
  type        = bool
  default     = true
  description = "Master switch. Set to false to skip all resource creation without removing the unit config."
}
