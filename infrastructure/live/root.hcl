# root.hcl — Terragrunt root configuration
# Inherited by all units in live/. Place this file at the top of infrastructure/live/.
# Each unit includes it via: find_in_parent_folders("root.hcl")
#
# PROVIDER CREDENTIALS ARE NOT GENERATED HERE.
# Each catalog stack module owns its own providers.tf because credential scope differs:
#   - catalog/stacks/cloudstack-platform → uses cloudstack.admin provider alias
#   - all other stacks                   → uses cloudstack.homecloud domain user
# Only terraform version + required_providers are injected centrally.

locals {
  # Read account-level config from the nearest account.hcl
  account_vars = read_terragrunt_config(find_in_parent_folders("account.hcl"))
}

# ─── Remote State ────────────────────────────────────────────────────────────
# Local backend for now; migrate to S3/GCS later.
remote_state {
  backend = "local"

  generate = {
    path      = "backend.tf"
    if_exists = "overwrite_terragrunt"
  }

  config = {
    path = "${get_repo_root()}/.tfstate/${path_relative_to_include()}/terraform.tfstate"
  }
}

# ─── Provider Version Constraints ────────────────────────────────────────────
# Injects ONLY required_providers into every unit. No provider configs here.
# Actual provider configuration (API keys, endpoints) lives in each catalog
# stack's providers.tf so that admin vs. domain-user scope is explicit.
generate "versions" {
  path      = "versions.tf"
  if_exists = "overwrite_terragrunt"

  contents = <<-EOF
    terraform {
      required_version = ">= 1.14.0"

      required_providers {
        cloudstack = {
          source  = "apache/cloudstack"
          version = "~> 0.5"
        }
        tailscale = {
          source  = "tailscale/tailscale"
          version = "~> 0.18"
        }
        onepassword = {
          source  = "1Password/onepassword"
          version = "~> 2.1"
        }
        talos = {
          source  = "siderolabs/talos"
          version = "~> 0.7"
        }
        helm = {
          source  = "hashicorp/helm"
          version = "~> 2.17"
        }
        kubernetes = {
          source  = "hashicorp/kubernetes"
          version = "~> 2.36"
        }
        local = {
          source  = "hashicorp/local"
          version = "~> 2.5"
        }
        null = {
          source  = "hashicorp/null"
          version = "~> 3.2"
        }
        random = {
          source  = "hashicorp/random"
          version = "~> 3.7"
        }
      }
    }
  EOF
}

# ─── Common Inputs ────────────────────────────────────────────────────────────
# Values available to every unit. Units can override as needed.
inputs = merge(
  local.account_vars.locals,
  {}
)
