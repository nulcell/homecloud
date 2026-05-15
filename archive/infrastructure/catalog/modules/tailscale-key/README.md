# tailscale-key

Generates a Tailscale auth key via the Tailscale API.

## Description

This module creates a `tailscale_tailnet_key` resource that produces a one-time
(or reusable) auth key for authenticating new Tailscale nodes. It is used by the
`tailscale-vpn` stack to bootstrap `homecloud-vpn-router` without storing a
long-lived key in state.

## Usage

```hcl
module "tailscale_key" {
  source = "../../modules/tailscale-key"

  description    = "homecloud-vpn-router"
  reusable       = false
  ephemeral      = false
  tags           = ["tag:subnet-router"]
  expiry_seconds = 3600
}
```

The `TAILSCALE_API_KEY` environment variable (or a configured `tailscale` provider
block) must be present for authentication.

## Inputs

| Name | Type | Description | Default | Required |
|------|------|-------------|---------|----------|
| `description` | `string` | Human-readable description for the auth key. | `"homecloud-vpn-router"` | no |
| `reusable` | `bool` | Whether the auth key can be used more than once. | `false` | no |
| `ephemeral` | `bool` | Whether devices that use this key are marked ephemeral. | `false` | no |
| `tags` | `list(string)` | ACL tags to apply to devices that authenticate with this key. | `["tag:subnet-router"]` | no |
| `expiry_seconds` | `number` | Key expiry in seconds from creation. | `3600` | no |

## Outputs

| Name | Description | Sensitive |
|------|-------------|-----------|
| `key` | The Tailscale auth key value. | yes |
