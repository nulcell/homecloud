terraform {
  required_version = ">= 1.14.0"

  required_providers {
    talos = {
      source  = "siderolabs/talos"
      version = "~> 0.10"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 3.1"
      # Configured in the calling stack (talos-cluster/providers.tf) with the
      # cluster's kubeconfig path. No alias needed — one helm provider per
      # terragrunt live unit (ops-cluster, workload-cluster).
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.7"
    }
  }
}
