terraform {
  required_version = ">= 1.5.0"

  required_providers {
    onepassword = {
      source  = "1Password/onepassword"
      version = "~> 3.3"
    }
  }
}
