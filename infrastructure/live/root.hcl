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

  # Provider versions last verified: 2026-03-25
  # Sources: registry.terraform.io + GitHub releases (stable only, no pre-releases)
  #   apache/cloudstack        0.6.0  (github.com/apache/cloudstack-terraform-provider)
  #   tailscale/tailscale      0.28.0 (registry.terraform.io)
  #   1Password/onepassword    3.3.1  (registry.terraform.io)
  #   siderolabs/talos         0.10.1 (latest stable; 0.11.0-beta.1 skipped)
  #   hashicorp/helm           3.1.1  (registry.terraform.io)
  #   hashicorp/kubernetes     3.0.1  (registry.terraform.io)
  #   hashicorp/local          2.7.0  (registry.terraform.io)
  #   hashicorp/null           3.2.4  (registry.terraform.io)
  #   hashicorp/random         3.8.1  (registry.terraform.io)
  #   hashicorp/external       2.3.5  (registry.terraform.io)
  #   cloudflare/cloudflare    4.52.7 (latest stable; v5.x is still beta)
  contents = <<-EOF
    terraform {
      required_version = ">= 1.14.0"

      required_providers {
        cloudstack = {
          source  = "cloudstack/cloudstack"
          version = "~> 0.6"
        }
        tailscale = {
          source  = "tailscale/tailscale"
          version = "~> 0.28"
        }
        onepassword = {
          source  = "1Password/onepassword"
          version = "~> 3.3"
        }
        talos = {
          source  = "siderolabs/talos"
          version = "~> 0.10.1"
        }
        helm = {
          source  = "hashicorp/helm"
          version = "~> 3.1"
        }
        kubernetes = {
          source  = "hashicorp/kubernetes"
          version = "~> 3.0"
        }
        cloudflare = {
          source  = "cloudflare/cloudflare"
          version = "~> 4.52"
        }
        local = {
          source  = "hashicorp/local"
          version = "~> 2.7"
        }
        null = {
          source  = "hashicorp/null"
          version = "~> 3.2"
        }
        random = {
          source  = "hashicorp/random"
          version = "~> 3.8"
        }
        external = {
          source  = "hashicorp/external"
          version = "~> 2.3"
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
