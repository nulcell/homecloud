#!/usr/bin/env bash
# Native Swift installer for the homecloud single-node OpenStack.
#
# kolla-ansible 2025.1 dropped its Swift role, so Swift runs as host-native
# services (apt-installed) alongside the kolla containers and is registered
# with Keystone as the `object-store` endpoint.
#
# Prerequisites:
#   - install.sh + configure.sh have completed successfully
#   - /etc/kolla/admin-openrc.sh exists and works
#   - The host has free disk for SWIFT_LOOP_SIZE × 3 under /srv/loopback/
#
# Usage:
#   sudo -E ./install-swift.sh                # build + start + register
#   sudo -E REINSTALL=1 ./install-swift.sh    # rebuild rings (destroys data)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ADMIN_OPENRC="/etc/kolla/admin-openrc.sh"
KOLLA_VENV="${KOLLA_VENV:-/opt/kolla/venv}"
KOLLA_GLOBALS="${KOLLA_GLOBALS:-/etc/kolla/globals.yml}"

# Loopback layout — same pattern the previous kolla swift role used.
SWIFT_LOOP_DIR="${SWIFT_LOOP_DIR:-/srv/loopback}"
SWIFT_MOUNT_DIR="${SWIFT_MOUNT_DIR:-/srv/node}"
SWIFT_LOOP_SIZE="${SWIFT_LOOP_SIZE:-50G}"
SWIFT_DEVICES=("d0" "d1" "d2")
SWIFT_LABEL="swift"

# Ring sizing — single-node 3 replicas, 1024 partitions (2^10).
SWIFT_PART_POWER="${SWIFT_PART_POWER:-10}"
SWIFT_REPLICAS="${SWIFT_REPLICAS:-3}"
SWIFT_MIN_HOURS="${SWIFT_MIN_HOURS:-1}"

REINSTALL="${REINSTALL:-0}"

log()  { printf "\033[1;34m[swift]\033[0m %s\n" "$*"; }
warn() { printf "\033[1;33m[swift]\033[0m %s\n" "$*" >&2; }
fail() { printf "\033[1;31m[swift]\033[0m %s\n" "$*" >&2; exit 1; }

OS() {
  if [[ -x "${KOLLA_VENV}/bin/openstack" ]]; then
    "${KOLLA_VENV}/bin/openstack" "$@"
  else
    openstack "$@"
  fi
}

require_root() {
  [[ $EUID -eq 0 ]] || fail "Run as root (sudo -E ./install-swift.sh)."
}

source_admin() {
  [[ -f "${ADMIN_OPENRC}" ]] || fail "Missing ${ADMIN_OPENRC}. Run install.sh first."
  # shellcheck disable=SC1090
  source "${ADMIN_OPENRC}"
  OS endpoint list >/dev/null || fail "Keystone unreachable — is OpenStack up?"
}

detect_host_ip() {
  local nic
  nic="$(awk '/^network_interface:/ {gsub(/"/,"",$2); print $2}' "${KOLLA_GLOBALS}")"
  [[ -n "${nic}" ]] || fail "Could not parse network_interface from ${KOLLA_GLOBALS}"
  ip -4 -o addr show "${nic}" | awk '{print $4}' | cut -d/ -f1 | head -n1
}

apt_install() {
  log "Installing swift packages"
  export DEBIAN_FRONTEND=noninteractive
  apt-get update -qq
  apt-get install -y --no-install-recommends \
    swift swift-account swift-container swift-object swift-proxy \
    python3-swift python3-keystonemiddleware \
    memcached rsync xfsprogs
  systemctl enable --now memcached
}

setup_loopbacks() {
  log "Setting up loopback devices for Swift"
  mkdir -p "${SWIFT_LOOP_DIR}" "${SWIFT_MOUNT_DIR}"

  for dev in "${SWIFT_DEVICES[@]}"; do
    local file="${SWIFT_LOOP_DIR}/${dev}.img"
    local mount="${SWIFT_MOUNT_DIR}/${dev}"
    local label="${SWIFT_LABEL}-${dev}"

    if [[ "${REINSTALL}" == "1" && -f "${file}" ]]; then
      warn "  REINSTALL=1 — wiping ${file}"
      umount "${mount}" 2>/dev/null || true
      losetup -j "${file}" | awk -F: '{print $1}' | xargs -r losetup -d
      rm -f "${file}"
    fi

    if [[ ! -f "${file}" ]]; then
      log "  fallocate ${file} (${SWIFT_LOOP_SIZE})"
      fallocate -l "${SWIFT_LOOP_SIZE}" "${file}"
    fi

    local loop
    loop="$(losetup -j "${file}" | awk -F: '{print $1}' | head -n1)"
    if [[ -z "${loop}" ]]; then
      loop="$(losetup --find --show "${file}")"
    fi

    if ! blkid "${loop}" | grep -q 'TYPE="xfs"'; then
      log "  mkfs.xfs -L ${label} ${loop}"
      mkfs.xfs -L "${label}" -f "${loop}" >/dev/null
    fi

    mkdir -p "${mount}"
    if ! mountpoint -q "${mount}"; then
      mount -t xfs -o noatime,nodiratime,logbufs=8 "${loop}" "${mount}"
    fi
    chown -R swift:swift "${mount}"

    # Persist across reboots — a oneshot unit is more portable than fstab here.
    local svc="swift-loop-${dev}.service"
    if [[ ! -f "/etc/systemd/system/${svc}" ]]; then
      cat >"/etc/systemd/system/${svc}" <<EOF
[Unit]
Description=Swift loopback ${dev}
DefaultDependencies=no
After=local-fs.target
Before=swift-account.service swift-container.service swift-object.service swift-proxy.service

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/sbin/losetup -f ${file}
ExecStartPost=/bin/mount -t xfs -o noatime,nodiratime,logbufs=8 LABEL=${label} ${mount}
ExecStop=/bin/umount ${mount}

[Install]
WantedBy=local-fs.target
EOF
      systemctl daemon-reload
      systemctl enable "${svc}" >/dev/null
    fi
  done
}

build_rings() {
  log "Generating Swift rings"
  install -d -o swift -g swift /etc/swift

  if [[ "${REINSTALL}" == "1" ]]; then
    rm -f /etc/swift/{account,container,object}.{builder,ring.gz}
  fi

  local host_ip; host_ip="$(detect_host_ip)"
  for ring in account container object; do
    local port
    case "${ring}" in
      account)   port=6202 ;;
      container) port=6201 ;;
      object)    port=6200 ;;
    esac

    if [[ -f "/etc/swift/${ring}.ring.gz" ]]; then
      log "  ${ring}.ring.gz exists — skipping"
      continue
    fi

    swift-ring-builder "/etc/swift/${ring}.builder" \
      create "${SWIFT_PART_POWER}" "${SWIFT_REPLICAS}" "${SWIFT_MIN_HOURS}"
    for d in "${SWIFT_DEVICES[@]}"; do
      swift-ring-builder "/etc/swift/${ring}.builder" \
        add "r1z1-${host_ip}:${port}/${d}" 1
    done
    swift-ring-builder "/etc/swift/${ring}.builder" rebalance
  done

  chown -R swift:swift /etc/swift
}

write_swift_conf() {
  log "Writing /etc/swift/swift.conf"
  # Hash prefix/suffix are cluster-unique salts. Generate once, then keep.
  if [[ ! -f /etc/swift/swift.conf ]]; then
    local prefix suffix
    prefix="$(openssl rand -hex 16)"
    suffix="$(openssl rand -hex 16)"
    cat >/etc/swift/swift.conf <<EOF
[swift-hash]
swift_hash_path_prefix = ${prefix}
swift_hash_path_suffix = ${suffix}

[storage-policy:0]
name = Policy-0
default = yes
EOF
    chown swift:swift /etc/swift/swift.conf
    chmod 640 /etc/swift/swift.conf
  fi
}

write_storage_confs() {
  log "Writing storage server configs"
  local host_ip; host_ip="$(detect_host_ip)"

  cat >/etc/swift/account-server.conf <<EOF
[DEFAULT]
bind_ip = ${host_ip}
bind_port = 6202
user = swift
swift_dir = /etc/swift
devices = ${SWIFT_MOUNT_DIR}
mount_check = true

[pipeline:main]
pipeline = healthcheck recon account-server

[app:account-server]
use = egg:swift#account

[filter:healthcheck]
use = egg:swift#healthcheck

[filter:recon]
use = egg:swift#recon
recon_cache_path = /var/cache/swift

[account-replicator]
[account-auditor]
[account-reaper]
EOF

  cat >/etc/swift/container-server.conf <<EOF
[DEFAULT]
bind_ip = ${host_ip}
bind_port = 6201
user = swift
swift_dir = /etc/swift
devices = ${SWIFT_MOUNT_DIR}
mount_check = true

[pipeline:main]
pipeline = healthcheck recon container-server

[app:container-server]
use = egg:swift#container

[filter:healthcheck]
use = egg:swift#healthcheck

[filter:recon]
use = egg:swift#recon
recon_cache_path = /var/cache/swift

[container-replicator]
[container-updater]
[container-auditor]
[container-sync]
EOF

  cat >/etc/swift/object-server.conf <<EOF
[DEFAULT]
bind_ip = ${host_ip}
bind_port = 6200
user = swift
swift_dir = /etc/swift
devices = ${SWIFT_MOUNT_DIR}
mount_check = true

[pipeline:main]
pipeline = healthcheck recon object-server

[app:object-server]
use = egg:swift#object

[filter:healthcheck]
use = egg:swift#healthcheck

[filter:recon]
use = egg:swift#recon
recon_cache_path = /var/cache/swift

[object-replicator]
[object-reconstructor]
[object-updater]
[object-auditor]
EOF

  install -d -o swift -g swift /var/cache/swift
  chown -R swift:swift /etc/swift
}

write_proxy_conf() {
  log "Writing /etc/swift/proxy-server.conf (Keystone auth)"
  local vip; vip="$(awk '/^kolla_internal_vip_address:/ {gsub(/"/,"",$2); print $2}' "${KOLLA_GLOBALS}")"

  # Bind on 0.0.0.0 — single-node keepalived holds the kolla VIP on this same
  # host, so listening on all interfaces lets VIP-registered Keystone endpoints
  # (http://VIP:8080/v1/AUTH_*) resolve to this proxy without involving the
  # kolla HAProxy (which has no swift backend since 2025.1 dropped the role).
  cat >/etc/swift/proxy-server.conf <<EOF
[DEFAULT]
bind_ip = 0.0.0.0
bind_port = 8080
user = swift
swift_dir = /etc/swift

[pipeline:main]
pipeline = catch_errors gatekeeper healthcheck listing_formats cache authtoken keystoneauth slo dlo proxy-logging proxy-server

[app:proxy-server]
use = egg:swift#proxy
account_autocreate = true

[filter:catch_errors]
use = egg:swift#catch_errors

[filter:gatekeeper]
use = egg:swift#gatekeeper

[filter:healthcheck]
use = egg:swift#healthcheck

[filter:listing_formats]
use = egg:swift#listing_formats

[filter:cache]
use = egg:swift#memcache
memcache_servers = 127.0.0.1:11211

[filter:authtoken]
paste.filter_factory = keystonemiddleware.auth_token:filter_factory
www_authenticate_uri = http://${vip}:5000
auth_url = http://${vip}:5000
memcached_servers = 127.0.0.1:11211
auth_type = password
project_domain_name = Default
user_domain_name = Default
project_name = service
username = swift
password = ${SWIFT_KEYSTONE_PASSWORD}
delay_auth_decision = True
service_token_roles_required = True
service_type = object-store

[filter:keystoneauth]
use = egg:swift#keystoneauth
operator_roles = admin, swiftoperator, member

[filter:slo]
use = egg:swift#slo

[filter:dlo]
use = egg:swift#dlo

[filter:proxy-logging]
use = egg:swift#proxy_logging
EOF
  chown swift:swift /etc/swift/proxy-server.conf
  chmod 640 /etc/swift/proxy-server.conf
}

ensure_keystone_swift() {
  # Idempotent: returns existing password if user already exists.
  log "Registering swift in Keystone"

  if OS user show swift >/dev/null 2>&1; then
    log "  user 'swift' already exists — set SWIFT_KEYSTONE_PASSWORD to its current password"
    [[ -n "${SWIFT_KEYSTONE_PASSWORD:-}" ]] || \
      fail "swift user exists but SWIFT_KEYSTONE_PASSWORD not exported. Either delete the user (\`openstack user delete swift\`) or pass the password."
  else
    SWIFT_KEYSTONE_PASSWORD="${SWIFT_KEYSTONE_PASSWORD:-$(openssl rand -hex 24)}"
    OS user create --domain Default --project service \
      --password "${SWIFT_KEYSTONE_PASSWORD}" swift >/dev/null
    OS role add --project service --user swift admin
  fi
  export SWIFT_KEYSTONE_PASSWORD

  OS role show swiftoperator >/dev/null 2>&1 || OS role create swiftoperator >/dev/null

  if ! OS service show object-store >/dev/null 2>&1; then
    OS service create --name swift --description "OpenStack Object Storage" object-store >/dev/null
  fi

  local vip; vip="$(awk '/^kolla_internal_vip_address:/ {gsub(/"/,"",$2); print $2}' "${KOLLA_GLOBALS}")"
  for iface in public internal admin; do
    if ! OS endpoint list --service object-store --interface "${iface}" -f value -c URL | grep -q .; then
      local url
      if [[ "${iface}" == "admin" ]]; then
        url="http://${vip}:8080/v1"
      else
        url="http://${vip}:8080/v1/AUTH_%(project_id)s"
      fi
      OS endpoint create --region RegionOne object-store "${iface}" "${url}" >/dev/null
    fi
  done

  # Persist the password for future runs (root-only)
  install -m 600 -o root -g root /dev/null /etc/swift/.keystone-password
  printf 'SWIFT_KEYSTONE_PASSWORD=%s\n' "${SWIFT_KEYSTONE_PASSWORD}" >/etc/swift/.keystone-password
}

start_services() {
  log "Starting swift services"
  for svc in \
    swift-account \
    swift-account-replicator \
    swift-account-auditor \
    swift-account-reaper \
    swift-container \
    swift-container-replicator \
    swift-container-updater \
    swift-container-auditor \
    swift-container-sync \
    swift-object \
    swift-object-replicator \
    swift-object-updater \
    swift-object-auditor \
    swift-object-reconstructor \
    swift-proxy
  do
    systemctl enable --now "${svc}" 2>/dev/null || warn "Failed to start ${svc} (may not exist on this distro)"
  done
}

smoke_test() {
  log "Smoke test: swift stat"
  if OS object store account show >/dev/null 2>&1; then
    log "  Swift account access OK"
  else
    warn "  swift not reachable yet — give it 30s and run: openstack object store account show"
  fi
}

main() {
  require_root
  source_admin

  apt_install
  setup_loopbacks

  # Keystone first so the proxy config can embed the password.
  ensure_keystone_swift

  build_rings
  write_swift_conf
  write_storage_confs
  write_proxy_conf

  start_services
  smoke_test

  log "Swift install complete."
  log "  S3-compatible API: install python3-swiftclient or use the openstack CLI."
  log "  Examples:"
  log "    openstack container create demo"
  log "    openstack object create demo /etc/hosts"
  log "    openstack object list demo"
}

main "$@"
