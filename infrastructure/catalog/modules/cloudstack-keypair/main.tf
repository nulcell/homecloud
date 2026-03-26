# ---------------------------------------------------------------------------
# SSH Keypair
#
# Import ID is the keypair name (CloudStack uses name as the identifier).
# Import blocks must be placed in the root module (stack). See stack main.tf.
# ---------------------------------------------------------------------------
resource "cloudstack_ssh_keypair" "this" {
  name       = var.name
  public_key = var.public_key
}
