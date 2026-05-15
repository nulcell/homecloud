# cloudstack_limits uses string type names, not integers.
# Map from CloudStack resourcetype integer → provider type string.
locals {
  resource_type_map = {
    "0"  = "instance"
    "1"  = "ip"
    "2"  = "volume"
    "3"  = "snapshot"
    "4"  = "template"
    "5"  = "project"
    "6"  = "network"
    "7"  = "vpc"
    "8"  = "cpu"
    "9"  = "memory"
    "10" = "primarystorage"
    "11" = "secondarystorage"
  }
}
