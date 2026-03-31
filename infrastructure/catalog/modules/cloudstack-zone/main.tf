resource "cloudstack_zone" "this" {
  name          = var.zone_name
  dns1          = var.zone_dns1
  internal_dns1 = var.zone_internal_dns1
  network_type  = var.zone_network_type
}

resource "cloudstack_physical_network" "this" {
  for_each = var.physical_networks

  name                   = each.key
  zone_id                = cloudstack_zone.this.id
  isolation_methods      = [each.value.isolation_method]
  broadcast_domain_range = "ZONE"
  network_speed          = lookup(each.value, "network_speed", "10G")
  tags                   = lookup(each.value, "tags", null)
  vlan                   = lookup(each.value, "vlan_range", null)

  lifecycle {
    # network_speed is not tracked by CloudStack API after creation
    ignore_changes = [network_speed]
  }
}

resource "cloudstack_traffic_type" "this" {
  for_each = local.traffic_type_pairs

  physical_network_id = each.value.physical_network_id
  traffic_type        = each.value.traffic_type
  kvm_network_label   = each.value.kvm_label

  depends_on = [cloudstack_physical_network.this]

  lifecycle {
    # The provider's read function may return stale data for traffic_type after
    # import (returns the first traffic type for the network). Also, KVM/XEN
    # labels may drift if not explicitly managed. Ignore to prevent replacements.
    ignore_changes = [traffic_type, kvm_network_label, xen_network_label]
  }
}

# ---------------------------------------------------------------------------
# Enable physical networks.
# The cloudstack_physical_network resource in provider v0.6 has no state
# attribute, so we enable via cmk after traffic types are attached.
# ---------------------------------------------------------------------------
resource "null_resource" "enable_physical_network" {
  for_each = var.physical_networks

  triggers = {
    physical_network_id = cloudstack_physical_network.this[each.key].id
  }

  provisioner "local-exec" {
    command = "cmk -p ${var.cmk_profile} update physicalnetwork id='${cloudstack_physical_network.this[each.key].id}' state='Enabled'"
  }

  depends_on = [cloudstack_traffic_type.this]
}

# ---------------------------------------------------------------------------
# Enable network service providers.
# CloudStack auto-creates NSPs when a physical network is created but leaves
# them Disabled. We must update the existing auto-created NSPs via cmk rather
# than creating new ones (addNetworkServiceProvider creates duplicates without
# VR/ILB elements, causing "Provider is not ready" errors on enable).
# ---------------------------------------------------------------------------
resource "null_resource" "enable_nsp" {
  for_each = local.nsp_pairs

  triggers = {
    physical_network_id = each.value.physical_network_id
    nsp_name            = each.value.name
    service_list        = join(",", each.value.service_list)
  }

  provisioner "local-exec" {
    command = <<-EOT
      PROVIDER_NAME="${each.value.name}"
      PHYS_NET_ID="${each.value.physical_network_id}"
      SERVICE_LIST="${join(",", each.value.service_list)}"

      PROVIDER_ID=$(cmk -p ${var.cmk_profile} list networkserviceproviders \
        physicalnetworkid="$PHYS_NET_ID" name="$PROVIDER_NAME" \
        | jq -r '.networkserviceprovider[0].id // empty')

      if [ -z "$PROVIDER_ID" ]; then
        echo "NSP $PROVIDER_NAME not found on $PHYS_NET_ID, skipping."
        exit 0
      fi

      if [ -n "$SERVICE_LIST" ]; then
        echo "  Setting service list for $PROVIDER_NAME: $SERVICE_LIST"
        cmk -p ${var.cmk_profile} update networkserviceprovider \
          id="$PROVIDER_ID" servicelist="$SERVICE_LIST"
      fi

      if [ "$PROVIDER_NAME" = "VirtualRouter" ] || [ "$PROVIDER_NAME" = "VpcVirtualRouter" ]; then
        VR_ELEMENT_ID=$(cmk -p ${var.cmk_profile} list virtualrouterelements nspid="$PROVIDER_ID" \
          | jq -r '.virtualrouterelement[0].id // empty')
        if [ -n "$VR_ELEMENT_ID" ]; then
          echo "  Configuring VR element $VR_ELEMENT_ID for $PROVIDER_NAME..."
          cmk -p ${var.cmk_profile} configure virtualrouterelement id="$VR_ELEMENT_ID" enabled=true
        fi
      fi

      if [ "$PROVIDER_NAME" = "InternalLbVm" ]; then
        ILB_ELEMENT_ID=$(cmk -p ${var.cmk_profile} list internalloadbalancerelements nspid="$PROVIDER_ID" \
          | jq -r '.internalloadbalancerelement[0].id // empty')
        if [ -n "$ILB_ELEMENT_ID" ]; then
          echo "  Configuring InternalLbVm element $ILB_ELEMENT_ID..."
          cmk -p ${var.cmk_profile} configure internalloadbalancerelement id="$ILB_ELEMENT_ID" enabled=true
        fi
      fi

      echo "  Enabling NSP $PROVIDER_NAME (ID: $PROVIDER_ID)..."
      cmk -p ${var.cmk_profile} update networkserviceprovider id="$PROVIDER_ID" state="Enabled" \
        || echo "  Warning: Could not enable $PROVIDER_NAME (may not be applicable for this network type)"
    EOT
  }

  depends_on = [null_resource.enable_physical_network]
}

resource "cloudstack_vlan_ip_range" "this" {
  for_each = local.vlan_ip_ranges

  physical_network_id = each.value.physical_network_id
  zone_id             = cloudstack_zone.this.id
  gateway             = each.value.gateway
  netmask             = each.value.netmask
  start_ip            = each.value.start_ip
  end_ip              = each.value.end_ip
  vlan                = each.value.vlan
  for_virtual_network = true

  depends_on = [cloudstack_physical_network.this]
}

# ---------------------------------------------------------------------------
# Pod
# Import: set existing_pod_id = UUID to import.
#   cmk -p admin list pods zoneid=<zone_id> name=<name> --output text --filter id
# ---------------------------------------------------------------------------
resource "cloudstack_pod" "this" {
  name     = var.pod.name
  zone_id  = cloudstack_zone.this.id
  gateway  = var.pod.gateway
  netmask  = var.pod.netmask
  start_ip = var.pod.start_ip
  end_ip   = var.pod.end_ip

  depends_on = [null_resource.enable_physical_network]

  lifecycle {
    # allocation_state is managed by CloudStack and changes based on host availability
    ignore_changes = [allocation_state]
  }
}

# ---------------------------------------------------------------------------
# KVM Cluster
# Import: set existing_cluster_id = UUID to import.
#   cmk -p admin list clusters zoneid=<zone_id> clustername=<name> --output text --filter id
# ---------------------------------------------------------------------------
resource "cloudstack_cluster" "this" {
  cluster_name = var.cluster.name
  cluster_type = "CloudManaged"
  hypervisor   = var.cluster.hypervisor
  pod_id       = cloudstack_pod.this.id
  zone_id      = cloudstack_zone.this.id

  depends_on = [cloudstack_pod.this]
}

# ---------------------------------------------------------------------------
# KVM Hosts — no native cloudstack_host resource in provider v0.6.
# Use null_resource + cmk with stable triggers (re-runs only if host config changes).
# ---------------------------------------------------------------------------
resource "null_resource" "host" {
  for_each = var.hosts

  triggers = {
    host_ip    = each.key
    cluster_id = cloudstack_cluster.this.id
    username   = each.value.username
  }

  provisioner "local-exec" {
    command = <<-EOT
      EXISTING=$(cmk -p ${var.cmk_profile} list hosts \
        zoneid='${cloudstack_zone.this.id}' \
        --output text --filter name 2>/dev/null | grep -c '${each.key}' || true)
      if [ "$EXISTING" -eq 0 ]; then
        cmk -p ${var.cmk_profile} add host \
          zoneid='${cloudstack_zone.this.id}' \
          clusterid='${cloudstack_cluster.this.id}' \
          podid='${cloudstack_pod.this.id}' \
          hypervisor='${var.cluster.hypervisor}' \
          url='http://${each.key}' \
          username='${each.value.username}'
      else
        echo "Host ${each.key} already present, skipping."
      fi
    EOT
  }

  depends_on = [cloudstack_cluster.this]
}

# ---------------------------------------------------------------------------
# Primary Storage Pools (NFS)
# Import: set existing_storage_pool_ids[name] = UUID to import.
#   cmk -p admin list storagepools zoneid=<zone_id> --output text --filter id,name
# ---------------------------------------------------------------------------

resource "cloudstack_storage_pool" "primary" {
  for_each = var.primary_storage_pools

  name       = each.key
  url        = "nfs://${each.value.server}${each.value.path}"
  zone_id    = cloudstack_zone.this.id
  hypervisor = "KVM"
  scope      = "ZONE"

  depends_on = [null_resource.host]

  lifecycle {
    # The provider reads back hypervisor from CloudStack (KVM) but it's not a
    # writable config attribute. The url field is ForceNew and may not be read
    # back correctly after import; ignore both to prevent spurious replacements.
    ignore_changes = [url, hypervisor]
  }
}

# ---------------------------------------------------------------------------
# Secondary Storage (Image Stores)
# Import: set existing_secondary_storage_ids[name] = UUID to import.
#   cmk -p admin list imageStores zoneid=<zone_id>
# ---------------------------------------------------------------------------

resource "cloudstack_secondary_storage" "this" {
  for_each = var.secondary_storage

  name             = each.key
  storage_provider = "NFS"
  url              = "nfs://${each.value.server}${each.value.path}"
  zone_id          = cloudstack_zone.this.id

  depends_on = [null_resource.host]
}

# ---------------------------------------------------------------------------
# Enable Zone
# Must run after all storage is configured. The zone starts in Disabled state.
# ---------------------------------------------------------------------------
resource "null_resource" "enable_zone" {
  triggers = {
    zone_id = cloudstack_zone.this.id
  }

  provisioner "local-exec" {
    command = <<-EOT
      echo "Enabling zone ${var.zone_name} (${cloudstack_zone.this.id})..."
      cmk -p ${var.cmk_profile} update zone \
        id="${cloudstack_zone.this.id}" \
        allocationstate="Enabled"
      echo "Zone enabled."
    EOT
  }

  depends_on = [
    cloudstack_storage_pool.primary,
    cloudstack_secondary_storage.this,
  ]
}
