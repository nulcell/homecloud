variable "cluster_name" {
  type        = string
  description = "Name of the Talos / Kubernetes cluster."
}

variable "cluster_endpoint" {
  type        = string
  description = "Kubernetes API server endpoint (https://<LB_IP>:6443)."
}

variable "kubernetes_version" {
  type        = string
  default     = "1.32.0"
  description = "Kubernetes version to install."
}

variable "talos_version" {
  type        = string
  default     = "v1.12.6"
  description = "Talos Linux version (e.g. v1.12.6)."
}

variable "control_plane_count" {
  type        = number
  default     = 1
  description = "Number of control plane nodes (informational; does not affect config generation)."
}

variable "worker_count" {
  type        = number
  default     = 1
  description = "Number of worker nodes (informational; does not affect config generation)."
}

variable "install_disk" {
  type        = string
  default     = "/dev/vda"
  description = "Block device path where Talos should be installed on each node."
}

variable "pod_subnet" {
  type        = string
  default     = "10.244.0.0/16"
  description = "CIDR block for pod networking."
}

variable "service_subnet" {
  type        = string
  default     = "10.96.0.0/12"
  description = "CIDR block for Kubernetes service networking."
}

variable "extra_config_patches" {
  type        = list(string)
  default     = []
  description = "List of Talos machine config patch YAML strings to merge into the controlplane config."
}
