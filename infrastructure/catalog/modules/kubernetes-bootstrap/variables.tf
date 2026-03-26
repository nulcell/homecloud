variable "cluster_name" {
  type        = string
  description = "Name of the cluster; used for kubeconfig filename and Helm release names."
}

variable "cluster_endpoint" {
  type        = string
  description = "Kubernetes API server endpoint (https://<LB_IP>:6443)."
}

variable "client_configuration" {
  type = object({
    ca_certificate     = string
    client_certificate = string
    client_key         = string
  })
  sensitive   = true
  description = "Talos client configuration object from talos_machine_secrets."
}

variable "controlplane_ips" {
  type        = list(string)
  description = "Private IP addresses of all control plane nodes."
}

variable "worker_ips" {
  type        = list(string)
  default     = []
  description = "Private IP addresses of all worker nodes (optional for health check)."
}

variable "enable_argocd" {
  type        = bool
  default     = false
  description = "Install ArgoCD via Helm."
}

variable "enable_cert_manager" {
  type        = bool
  default     = false
  description = "Install cert-manager via Helm."
}

variable "enable_external_dns" {
  type        = bool
  default     = false
  description = "Install external-dns via Helm."
}

variable "enable_csi" {
  type        = bool
  default     = true
  description = "Install the CloudStack CSI driver via Helm."
}

variable "enable_ccm" {
  type        = bool
  default     = true
  description = "Install the CloudStack Cloud Controller Manager via Helm."
}

variable "cilium_version" {
  type        = string
  default     = "1.17.0"
  description = "Cilium Helm chart version."
}

variable "ccm_version" {
  type        = string
  default     = "0.4.0"
  description = "CloudStack CCM Helm chart version."
}

variable "csi_version" {
  type        = string
  default     = "0.4.0"
  description = "CloudStack CSI Helm chart version."
}

variable "argocd_version" {
  type        = string
  default     = "7.8.0"
  description = "ArgoCD Helm chart version."
}

variable "cert_manager_version" {
  type        = string
  default     = "1.17.0"
  description = "cert-manager Helm chart version."
}

variable "external_dns_version" {
  type        = string
  default     = "8.7.1"
  description = "external-dns Helm chart version."
}

variable "cloudstack_api_url" {
  type        = string
  description = "CloudStack API endpoint URL (passed to CCM and CSI)."
}

variable "cloudstack_api_key" {
  type        = string
  sensitive   = true
  description = "CloudStack API key (passed to CCM and CSI)."
}

variable "cloudstack_secret_key" {
  type        = string
  sensitive   = true
  description = "CloudStack secret key (passed to CCM and CSI)."
}

variable "cloudstack_zone_name" {
  type        = string
  description = "CloudStack zone name (passed to CCM and CSI)."
}

variable "cloudflare_api_token" {
  type        = string
  default     = ""
  sensitive   = true
  description = "Cloudflare API token for external-dns (required when enable_external_dns = true)."
}

variable "cloudflare_zone_ids" {
  type        = map(string)
  default     = {}
  description = "Map of DNS zone name to Cloudflare zone ID (used by external-dns)."
}
