locals {
  fixed_compute = {
    for k, v in var.compute_offerings : k => v
    if v.disk_type == "fixed"
  }
  unconstrained_compute = {
    for k, v in var.compute_offerings : k => v
    if contains(["custom_shared", "custom_local"], v.disk_type)
  }
  constrained_compute = {
    for k, v in var.compute_offerings : k => v
    if v.disk_type == "customized"
  }
}
