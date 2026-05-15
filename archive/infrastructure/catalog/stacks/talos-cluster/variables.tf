variable "cloudstack_api_url" {
  type        = string
  description = "CloudStack API endpoint URL."
}

variable "zone_name" {
  type        = string
  default     = "zone-homecloud"
  description = "Name of the CloudStack zone."
}

variable "account_name" {
  type        = string
  default     = "homecloud"
  description = "CloudStack account name."
}

variable "domain_id" {
  type        = string
  default     = ""
  description = "UUID of the CloudStack domain. Leave empty when the API key is already scoped to the domain."
}

variable "network_id" {
  type        = string
  description = "Primary network UUID for cluster nodes."
}

variable "vpc_id" {
  type        = string
  default     = ""
  description = "VPC UUID for public IP allocation. Leave empty for isolated-network clusters."
}

variable "template_name" {
  type        = string
  description = "Name of the Talos Linux VM template (e.g. 'talos-v1.12.6')."
}

variable "keypair_name" {
  type        = string
  description = "Name of the SSH keypair to inject into VMs."
}

variable "compute_offering_name" {
  type        = string
  description = "Name of the CloudStack service offering for control plane and worker VMs (e.g. 'gen.large')."
}

variable "cluster_name" {
  type        = string
  description = "Name of the Talos / Kubernetes cluster."
}

variable "is_ops" {
  type        = bool
  default     = false
  description = "Set to true for the ops cluster (isolated network, ArgoCD installed)."
}

variable "controlplane_count" {
  type        = number
  default     = 1
  description = "Number of control plane nodes."
}

variable "worker_count" {
  type        = number
  default     = 1
  description = "Number of worker nodes."
}

variable "control_plane_disk_size" {
  type        = number
  default     = 30
  description = "Root disk size for control plane VMs in GB."
}

variable "worker_disk_size" {
  type        = number
  default     = 50
  description = "Root disk size for worker VMs in GB."
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

variable "talos_config_patches" {
  type        = list(string)
  default     = []
  description = "List of Talos machine config patch YAML strings applied to control plane nodes."
}

variable "enable_argocd" {
  type        = bool
  default     = false
  description = "Install ArgoCD on this cluster."
}

variable "enable_cloudstack_ccm" {
  type        = bool
  default     = true
  description = "Install the CloudStack Cloud Controller Manager."
}

variable "enable_cloudstack_csi" {
  type        = bool
  default     = true
  description = "Install the CloudStack CSI driver."
}

variable "enable_external_dns" {
  type        = bool
  default     = false
  description = "Install external-dns."
}

variable "enable_cert_manager" {
  type        = bool
  default     = false
  description = "Install cert-manager."
}

variable "cloudflare_zone" {
  type        = string
  default     = ""
  description = "Cloudflare DNS zone name (used by external-dns)."
}

variable "argocd_server_url" {
  type        = string
  default     = ""
  description = "ArgoCD server URL (used by workload cluster for app registration)."
}

variable "op_vault" {
  type        = string
  default     = "homecloud"
  description = "1Password vault name or UUID where cluster credentials are stored."
}

variable "op_account" {
  type        = string
  description = "1Password account URL (e.g. my.1password.com) for CLI-based provider auth."
}

variable "cilium_version" {
  type        = string
  default     = "1.19.2"
  description = "Cilium Helm chart version."
}

variable "ccm_manifest_url" {
  type        = string
  default     = "https://github.com/apache/cloudstack-kubernetes-provider/releases/download/v1.2.0/deployment.yaml"
  description = "URL for the CloudStack CCM deployment manifest."
}

variable "csi_snapshot_crds_url" {
  type        = string
  default     = "https://github.com/cloudstack/cloudstack-csi-driver/releases/download/cloudstack-csi-3.0.1/snapshot-crds.yaml"
  description = "URL for the CSI snapshot CRDs manifest."
}

variable "csi_manifest_url" {
  type        = string
  default     = "https://github.com/cloudstack/cloudstack-csi-driver/releases/download/cloudstack-csi-3.0.1/manifest.yaml"
  description = "URL for the CloudStack CSI driver manifest."
}

variable "argocd_version" {
  type        = string
  default     = "9.4.17"
  description = "ArgoCD Helm chart version (app version v3.3.6)."
}

variable "cert_manager_version" {
  type        = string
  default     = "v1.20.1"
  description = "cert-manager Helm chart version."
}

variable "external_dns_version" {
  type        = string
  default     = "1.20.0"
  description = "external-dns Helm chart version."
}

variable "is_enabled" {
  type        = bool
  default     = true
  description = "Master switch. Set to false to skip all resource creation without removing the unit config."
}
