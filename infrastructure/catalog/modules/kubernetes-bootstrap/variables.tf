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
  description = "Install the CloudStack CSI driver via kubectl manifest."
}

variable "enable_ccm" {
  type        = bool
  default     = true
  description = "Install the CloudStack Cloud Controller Manager via kubectl manifest."
}

variable "cilium_version" {
  type        = string
  default     = "1.19.2"
  description = "Cilium Helm chart version."
}

variable "ccm_manifest_url" {
  type        = string
  default     = "https://github.com/apache/cloudstack-kubernetes-provider/releases/download/v1.2.0/deployment.yaml"
  description = "URL for the CloudStack CCM (cloudstack-kubernetes-provider) deployment manifest."
}

variable "csi_snapshot_crds_url" {
  type        = string
  default     = "https://github.com/cloudstack/cloudstack-csi-driver/releases/download/cloudstack-csi-3.0.1/snapshot-crds.yaml"
  description = "URL for the CSI snapshot CRDs manifest (must be applied before the main CSI manifest)."
}

variable "csi_manifest_url" {
  type        = string
  default     = "https://github.com/cloudstack/cloudstack-csi-driver/releases/download/cloudstack-csi-3.0.1/manifest.yaml"
  description = "URL for the CloudStack CSI driver manifest. A sed fix for a known typo is applied automatically."
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
