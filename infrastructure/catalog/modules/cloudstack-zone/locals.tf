locals {
  traffic_type_pairs = merge([
    for net_name, net in var.physical_networks : {
      for tt in net.traffic_types :
      "${net_name}/${tt}" => {
        physical_network_id = cloudstack_physical_network.this[net_name].id
        traffic_type        = tt
        kvm_label           = lookup(lookup(net, "kvm_labels", {}), tt, null)
      }
    }
  ]...)
}

locals {
  nsp_pairs = merge([
    for net_name, net in var.physical_networks : {
      for prov in net.service_providers :
      "${net_name}/${prov.name}" => {
        physical_network_id = cloudstack_physical_network.this[net_name].id
        name                = prov.name
        service_list        = lookup(prov, "service_list", null)
      }
    }
  ]...)
}

locals {
  vlan_ip_ranges = merge([
    for net_name, net in var.physical_networks : net.public_ip_range != null ? {
      "${net_name}" = {
        physical_network_id = cloudstack_physical_network.this[net_name].id
        gateway             = net.public_ip_range.gateway
        netmask             = net.public_ip_range.netmask
        start_ip            = net.public_ip_range.start_ip
        end_ip              = net.public_ip_range.end_ip
        vlan                = net.public_ip_range.vlan
      }
    } : {}
  ]...)
}
