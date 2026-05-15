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
  }
}
