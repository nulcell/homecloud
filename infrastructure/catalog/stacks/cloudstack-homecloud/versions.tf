terraform {
  required_version = ">= 1.14.0"

  required_providers {
    cloudstack = {
      source  = "cloudstack/cloudstack"
      version = "~> 0.6"
    }
    onepassword = {
      source  = "1Password/onepassword"
      version = "~> 3.3"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.2"
    }
  }
}
