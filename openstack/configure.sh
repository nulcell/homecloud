#!/usr/bin/env bash
# Post-deploy configuration: images, flavors, networks, security groups, magnum templates.
# Run AFTER install.sh has finished a successful kolla-ansible deploy.
#
# Idempotent — checks for existing resources before creating.
#
# Tweak via env vars:
#   PROVIDER_CIDR      external network CIDR        (default: 10.10.16.0/20)
#   PROVIDER_GATEWAY   upstream gateway             (default: 10.10.31.254)
#   PROVIDER_POOL      floating IP allocation pool  (default: 10.10.20.0–10.10.20.254)
#   PROVIDER_DNS       DNS server for tenants       (default: 10.10.31.254)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KOLLA_VENV="${KOLLA_VENV:-/opt/kolla/venv}"
ADMIN_OPENRC="/etc/kolla/admin-openrc.sh"

PROVIDER_CIDR="${PROVIDER_CIDR:-10.10.16.0/20}"
PROVIDER_GATEWAY="${PROVIDER_GATEWAY:-10.10.31.254}"
PROVIDER_POOL="${PROVIDER_POOL:-start=10.10.20.0,end=10.10.20.254}"
PROVIDER_DNS="${PROVIDER_DNS:-10.10.31.254}"

IMAGES_DIR="${IMAGES_DIR:-/var/lib/openstack-images}"

log()  { printf "\033[1;34m[configure]\033[0m %s\n" "$*"; }
warn() { printf "\033[1;33m[configure]\033[0m %s\n" "$*" >&2; }
fail() { printf "\033[1;31m[configure]\033[0m %s\n" "$*" >&2; exit 1; }

source_openrc() {
  [[ -f "${ADMIN_OPENRC}" ]] || fail "Missing ${ADMIN_OPENRC}. Run install.sh first."
  # shellcheck disable=SC1090
  source "${ADMIN_OPENRC}"
}

# Use openstack CLI from the kolla venv if installed there, else PATH
OS() {
  if [[ -x "${KOLLA_VENV}/bin/openstack" ]]; then
    "${KOLLA_VENV}/bin/openstack" "$@"
  else
    openstack "$@"
  fi
}

ensure_image() {
  local name="$1" url="$2" disk_format="$3" properties="${4:-}"
  if OS image show "${name}" >/dev/null 2>&1; then
    log "image '${name}' exists — skipping"
    return
  fi
  mkdir -p "${IMAGES_DIR}"
  local download="${IMAGES_DIR}/$(basename "${url}")"
  if [[ ! -f "${download}" ]]; then
    log "Downloading ${name} → ${download}"
    curl -L --fail --retry 3 -o "${download}" "${url}"
  fi

  # Decompress if needed. Output filename strips the compression suffix.
  local file="${download}"
  case "${download}" in
    *.xz)
      file="${download%.xz}"
      if [[ ! -f "${file}" ]]; then
        command -v xz >/dev/null || apt-get install -y xz-utils
        log "Decompressing ${download} (xz)"
        xz --decompress --keep --force "${download}"
      fi
      ;;
    *.gz)
      file="${download%.gz}"
      if [[ ! -f "${file}" ]]; then
        log "Decompressing ${download} (gz)"
        gunzip -k "${download}"
      fi
      ;;
    *.bz2)
      file="${download%.bz2}"
      if [[ ! -f "${file}" ]]; then
        log "Decompressing ${download} (bz2)"
        bunzip2 -k "${download}"
      fi
      ;;
  esac

  log "Uploading image '${name}'"
  # shellcheck disable=SC2086
  OS image create "${name}" \
    --disk-format "${disk_format}" \
    --container-format bare \
    --public \
    --file "${file}" \
    ${properties}
}

ensure_flavor() {
  local name="$1" ram="$2" disk="$3" vcpus="$4"
  if OS flavor show "${name}" >/dev/null 2>&1; then
    log "flavor '${name}' exists — skipping"
    return
  fi
  log "Creating flavor '${name}' (${vcpus}vCPU/${ram}MB/${disk}GB)"
  OS flavor create "${name}" --ram "${ram}" --disk "${disk}" --vcpus "${vcpus}" --public
}

ensure_external_network() {
  if OS network show public >/dev/null 2>&1; then
    log "network 'public' exists — skipping"
    return
  fi
  log "Creating external network 'public' (flat physnet1)"
  OS network create public \
    --external \
    --provider-network-type flat \
    --provider-physical-network physnet1 \
    --share

  OS subnet create public-subnet \
    --network public \
    --subnet-range "${PROVIDER_CIDR}" \
    --gateway "${PROVIDER_GATEWAY}" \
    --allocation-pool "${PROVIDER_POOL}" \
    --dns-nameserver "${PROVIDER_DNS}" \
    --no-dhcp
}

ensure_default_security_group() {
  log "Adding ssh + icmp + k8s ingress rules to default secgroup (project: admin)"
  local secgroup
  secgroup="$(OS security group list --project admin -f value -c ID -c Name | awk '$2=="default"{print $1}' | head -n1)"
  [[ -n "${secgroup}" ]] || { warn "Could not find default security group"; return; }
  for rule in "tcp:22" "tcp:80" "tcp:443" "tcp:6443" "tcp:30000:32767" "icmp:"; do
    local proto="${rule%%:*}"
    local ports="${rule#*:}"
    if [[ -z "${ports}" ]]; then
      OS security group rule create "${secgroup}" --protocol "${proto}" --remote-ip 0.0.0.0/0 >/dev/null 2>&1 || true
    elif [[ "${ports}" == *":"* ]]; then
      OS security group rule create "${secgroup}" --protocol "${proto}" \
        --dst-port "${ports}" --remote-ip 0.0.0.0/0 >/dev/null 2>&1 || true
    else
      OS security group rule create "${secgroup}" --protocol "${proto}" \
        --dst-port "${ports}" --remote-ip 0.0.0.0/0 >/dev/null 2>&1 || true
    fi
  done
}

ensure_keypair() {
  local name="${1:-os-admin}"
  if OS keypair show "${name}" >/dev/null 2>&1; then
    log "keypair '${name}' exists — skipping"
    return
  fi
  if [[ -f "${HOME}/.ssh/id_ed25519.pub" ]]; then
    log "Importing keypair '${name}' from ~/.ssh/id_ed25519.pub"
    OS keypair create --public-key "${HOME}/.ssh/id_ed25519.pub" "${name}"
  elif [[ -f "${HOME}/.ssh/id_rsa.pub" ]]; then
    log "Importing keypair '${name}' from ~/.ssh/id_rsa.pub"
    OS keypair create --public-key "${HOME}/.ssh/id_rsa.pub" "${name}"
  else
    warn "No SSH public key found in ~/.ssh — skipping keypair import"
  fi
}

register_trove_datastore() {
  # Args: datastore_name, version, image_name (may be empty), packages
  # If image is empty, the version is left "image-less" — Trove will refuse to
  # provision instances until you re-run with TROVE_*_IMAGE set, but the
  # datastore + version will already be registered.
  local ds="$1" ver="$2" image="$3" pkgs="$4"

  if ! OS datastore show "${ds}" >/dev/null 2>&1; then
    log "Creating Trove datastore '${ds}'"
    OS datastore create "${ds}" >/dev/null 2>&1 || true
  fi

  if OS datastore version show --datastore "${ds}" "${ver}" >/dev/null 2>&1; then
    log "Trove datastore version '${ds}/${ver}' exists — skipping"
    return
  fi

  if [[ -z "${image}" ]]; then
    warn "  no image set for ${ds}/${ver} — registering metadata only (set TROVE_${ds^^}_IMAGE later)"
    OS datastore version create "${ver}" "${ds}" "${ds}" "${pkgs}" 1 \
      --default >/dev/null 2>&1 || \
    OS datastore version create "${ver}" "${ds}" "${ds}" "${pkgs}" 1 || \
      warn "  failed to register ${ds}/${ver}"
    return
  fi

  log "  registering ${ds}/${ver} → image '${image}'"
  OS datastore version create "${ver}" "${ds}" "${ds}" "${pkgs}" 1 \
    --image "${image}" --default
}

ensure_magnum_template() {
  local name="$1" image="$2" coe="$3" network_driver="$4" extra="${5:-}"
  if OS coe cluster template show "${name}" >/dev/null 2>&1; then
    log "magnum template '${name}' exists — skipping"
    return
  fi
  log "Creating magnum cluster template '${name}'"
  # shellcheck disable=SC2086
  OS coe cluster template create "${name}" \
    --image "${image}" \
    --keypair os-admin \
    --external-network public \
    --master-flavor m1.large \
    --flavor m1.large \
    --volume-driver cinder \
    --docker-volume-size 25 \
    --network-driver "${network_driver}" \
    --coe "${coe}" \
    --master-lb-enabled \
    --floating-ip-enabled \
    --dns-nameserver "${PROVIDER_DNS}" \
    ${extra}
}

main() {
  source_openrc

  # ---------------------------------------------------------------------------
  # Images
  # ---------------------------------------------------------------------------
  log "Uploading base images"
  ensure_image "cirros" \
    "https://download.cirros-cloud.net/0.6.2/cirros-0.6.2-x86_64-disk.img" \
    "qcow2"

  ensure_image "ubuntu-24.04" \
    "https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img" \
    "qcow2" \
    "--property hw_disk_bus=virtio --property hw_qemu_guest_agent=yes --property os_distro=ubuntu --property os_version=24.04"

  ensure_image "ubuntu-22.04" \
    "https://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-amd64.img" \
    "qcow2" \
    "--property hw_disk_bus=virtio --property hw_qemu_guest_agent=yes --property os_distro=ubuntu --property os_version=22.04"

  ensure_image "debian-12" \
    "https://cloud.debian.org/images/cloud/bookworm/latest/debian-12-genericcloud-amd64.qcow2" \
    "qcow2" \
    "--property hw_disk_bus=virtio --property hw_qemu_guest_agent=yes --property os_distro=debian --property os_version=12"

  ensure_image "fedora-coreos-magnum" \
    "https://builds.coreos.fedoraproject.org/prod/streams/stable/builds/43.20260413.3.2/x86_64/fedora-coreos-43.20260413.3.2-openstack.x86_64.qcow2.xz" \
    "qcow2" \
    "--property os_distro=fedora-coreos --property hw_firmware_type=uefi"

  # ---------------------------------------------------------------------------
  # Flavors
  # ---------------------------------------------------------------------------
  log "Creating flavors"
  ensure_flavor "m1.tiny"    512    1  1
  ensure_flavor "m1.small"   2048  20  1
  ensure_flavor "m1.medium"  4096  40  2
  ensure_flavor "m1.large"   8192  80  4
  ensure_flavor "m1.xlarge" 16384 160  8
  ensure_flavor "m1.2xlarge" 32768 320 16
  ensure_flavor "k8s.master" 4096  40  2
  ensure_flavor "k8s.worker" 8192  80  4

  # ---------------------------------------------------------------------------
  # Networking
  # ---------------------------------------------------------------------------
  log "Configuring external network"
  ensure_external_network

  # ---------------------------------------------------------------------------
  # Defaults
  # ---------------------------------------------------------------------------
  ensure_default_security_group
  ensure_keypair os-admin

  # ---------------------------------------------------------------------------
  # Magnum cluster templates (managed Kubernetes)
  # ---------------------------------------------------------------------------
  if OS service show magnum >/dev/null 2>&1 || OS coe cluster template list >/dev/null 2>&1; then
    log "Creating magnum k8s cluster templates"
    ensure_magnum_template "k8s-fcos-calico" \
      "fedora-coreos-magnum" "kubernetes" "calico" \
      "--labels boot_volume_size=25,boot_volume_type=lvm-1,kube_tag=v1.30.4"
    ensure_magnum_template "k8s-fcos-cilium" \
      "fedora-coreos-magnum" "kubernetes" "cilium" \
      "--labels boot_volume_size=25,boot_volume_type=lvm-1,kube_tag=v1.30.4"
  else
    warn "Magnum service not available — skipping cluster templates"
  fi

  # ---------------------------------------------------------------------------
  # Manila default share type (LVM/NFS)
  # ---------------------------------------------------------------------------
  if OS service show manila >/dev/null 2>&1 || OS share type list >/dev/null 2>&1; then
    if ! OS share type show default >/dev/null 2>&1; then
      log "Creating manila default share type (DHSS=False, LVM)"
      OS share type create default false \
        --extra-specs share_backend_name=LVM
    else
      log "manila share type 'default' exists — skipping"
    fi
  fi

  # ---------------------------------------------------------------------------
  # Octavia (LBaaS) — confirm an amphora-tagged image exists. Without one,
  # `openstack loadbalancer create` will sit at PENDING_CREATE forever.
  # ---------------------------------------------------------------------------
  if OS service show octavia >/dev/null 2>&1 || OS loadbalancer provider list >/dev/null 2>&1; then
    local svc_pid amp_count
    svc_pid="$(OS project show service -f value -c id 2>/dev/null || true)"
    if [[ -n "${svc_pid}" ]]; then
      amp_count="$(OS image list --project "${svc_pid}" --tag amphora -f value -c ID | wc -l | tr -d ' ')"
      if [[ "${amp_count}" -eq 0 ]]; then
        warn "Octavia is enabled but no amphora-tagged image is in glance."
        warn "  Run: sudo -E ${SCRIPT_DIR}/build-amphora.sh"
        warn "  (LB create will fail until an amphora image is uploaded.)"
      else
        log "Octavia: ${amp_count} amphora image(s) present → ready for LB create"
      fi
    fi
  fi

  # ---------------------------------------------------------------------------
  # Designate — default DNS zone (homecloud.local) + delegate to public network
  # ---------------------------------------------------------------------------
  if OS service show designate >/dev/null 2>&1 || OS zone list >/dev/null 2>&1; then
    local zone_name="${DESIGNATE_ZONE:-homecloud.local.}"
    local zone_email="${DESIGNATE_EMAIL:-admin@homecloud.local}"
    if ! OS zone show "${zone_name}" >/dev/null 2>&1; then
      log "Creating Designate zone '${zone_name}'"
      OS zone create --email "${zone_email}" "${zone_name}"
    else
      log "Designate zone '${zone_name}' exists — skipping"
    fi

    # Tag the public network with this DNS domain so VM port creates auto-register
    # A/PTR records via the neutron-designate integration.
    if OS network show public >/dev/null 2>&1; then
      log "Setting dns_domain on 'public' network → ${zone_name}"
      OS network set --dns-domain "${zone_name}" public >/dev/null 2>&1 || true
    fi
  else
    warn "Designate service not available — skipping zone setup"
  fi

  # ---------------------------------------------------------------------------
  # Barbican — smoke test the secret store with a throwaway key
  # ---------------------------------------------------------------------------
  if OS service show barbican >/dev/null 2>&1 || OS secret list >/dev/null 2>&1; then
    if ! OS secret list -f value -c Name | grep -qx "homecloud-smoketest"; then
      log "Creating Barbican smoke-test secret 'homecloud-smoketest'"
      OS secret store \
        --name homecloud-smoketest \
        --algorithm aes \
        --bit-length 256 \
        --mode cbc \
        --payload "homecloud-barbican-ok" \
        --payload-content-type "text/plain" >/dev/null
    else
      log "Barbican smoke-test secret 'homecloud-smoketest' exists — skipping"
    fi
  else
    warn "Barbican service not available — skipping smoke test"
  fi

  # ---------------------------------------------------------------------------
  # Trove datastore versions
  # NOTE: Trove guest images must be built separately with diskimage-builder
  #       (https://docs.openstack.org/trove/latest/admin/building_guest_images.html).
  #       Once you've built and uploaded one, set TROVE_MYSQL_IMAGE / TROVE_PG_IMAGE
  #       to the glance image name and re-run this script to wire it up.
  # ---------------------------------------------------------------------------
  if OS service show trove >/dev/null 2>&1 || OS datastore list >/dev/null 2>&1; then
    log "Registering Trove datastore versions (image wiring requires guest images)"
    register_trove_datastore "mysql"      "8.0" "${TROVE_MYSQL_IMAGE:-}"      "mysql-server-8.0"
    register_trove_datastore "postgresql" "16"  "${TROVE_PG_IMAGE:-}"          "postgresql-16"
    register_trove_datastore "mariadb"    "11"  "${TROVE_MARIADB_IMAGE:-}"     "mariadb-server-11"
  else
    warn "Trove service not available — skipping datastore registration"
  fi

  log "Configuration complete."
  log ""
  log "Try: openstack image list"
  log "Try: openstack network list"
  log "Try: openstack flavor list"
  log "Try: openstack coe cluster template list"
  log "Try: openstack datastore list"
  log "Try: openstack secret list"
  log "Try: openstack zone list"
  log "Try: openstack loadbalancer provider list"
}

main "$@"
