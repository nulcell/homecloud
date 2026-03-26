terraform {
  required_version = ">= 1.14.0"

  required_providers {
    talos = {
      source  = "siderolabs/talos"
      version = "~> 0.10"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.2"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.7"
    }
  }
}
