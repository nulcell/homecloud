data "cloudstack_zone" "this" {
  filter {
    name  = "name"
    value = var.zone_name
  }
}
