# root.hcl — Terragrunt root configuration
# Inherited by all units in live/. Place this file at the top of infrastructure/live/.
# Each unit includes it via: find_in_parent_folders("root.hcl")

locals {
  # Read account-level config from the nearest account.hcl
  account_vars = read_terragrunt_config(find_in_parent_folders("account.hcl"))

  # Derived locals
  environment = local.account_vars.locals.environment
  stack_name  = local.account_vars.locals.stack_name
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

# ─── Provider Generation ─────────────────────────────────────────────────────
# Inject provider version constraints into every unit from a single source.
generate "versions" {
  path      = "versions.tf"
  if_exists = "overwrite_terragrunt"

  contents = <<-EOF
    terraform {
      required_version = ">= 1.11.0"

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
