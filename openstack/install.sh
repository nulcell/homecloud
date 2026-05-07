#!/usr/bin/env bash
# OpenStack single-node installer — runs after MaaS provisioning.
# Steps:
#   1. Sanity checks (root, OS, NICs, KVM)
#   2. Create LVM VGs for cinder + manila
#   3. Render kolla passwords + admin openrc
#   4. Validate VIP is free
#   5. kolla-ansible install-deps / bootstrap-servers / prechecks / deploy / post-deploy
#
# Idempotent enough to re-run after fixing a config error.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KOLLA_DIR="${SCRIPT_DIR}/homecloud-kolla-ansible"
KOLLA_VENV="${KOLLA_VENV:-/opt/kolla/venv}"
KOLLA_CONFIG_DIR="/etc/kolla"
KOLLA_PASSWORDS="${KOLLA_CONFIG_DIR}/passwords.yml"
KOLLA_GLOBALS="${KOLLA_CONFIG_DIR}/globals.yml"

# Defaults — override by exporting before invocation
CINDER_VG="${CINDER_VG:-cinder-volumes}"
MANILA_VG="${MANILA_VG:-manila-volumes}"
CINDER_LOOP_SIZE="${CINDER_LOOP_SIZE:-1500G}"     # used only if CINDER_LVM_DEVICE unset
MANILA_LOOP_SIZE="${MANILA_LOOP_SIZE:-200G}"
CINDER_LOOP_FILE="/var/lib/cinder/cinder-volumes.img"
MANILA_LOOP_FILE="/var/lib/manila/manila-volumes.img"

log()  { printf "\033[1;34m[install]\033[0m %s\n" "$*"; }
warn() { printf "\033[1;33m[install]\033[0m %s\n" "$*" >&2; }
fail() { printf "\033[1;31m[install]\033[0m %s\n" "$*" >&2; exit 1; }

require_root() {
  [[ $EUID -eq 0 ]] || fail "Run as root (sudo -E ./install.sh)."
}

require_ubuntu_2404() {
  . /etc/os-release
  [[ "${ID}" == "ubuntu" && "${VERSION_ID}" == "24.04" ]] \
    || fail "Expected Ubuntu 24.04. Found ${ID} ${VERSION_ID}."
}

check_kvm() {
  if ! kvm-ok >/dev/null 2>&1; then
    fail "KVM acceleration not available. Enable Intel VT-x / AMD-V in BIOS."
  fi
}

ensure_lvm_vg() {
  local vg="$1" device="${2:-}"
  if vgs "${vg}" >/dev/null 2>&1; then
    log "VG ${vg} already exists — skipping."
    return
  fi
  if [[ -n "${device}" ]]; then
    log "Creating PV+VG ${vg} on ${device}"
    pvcreate -ff -y "${device}"
    vgcreate "${vg}" "${device}"
  else
    fail "ensure_lvm_vg called without a device for ${vg}"
  fi
}

ensure_lvm_vg_loopback() {
  local vg="$1" file="$2" size="$3"
  if vgs "${vg}" >/dev/null 2>&1; then
    log "VG ${vg} already exists — skipping."
    return
  fi
  log "Creating loopback-backed VG ${vg} (${size}) at ${file}"
  mkdir -p "$(dirname "${file}")"
  truncate -s "${size}" "${file}"
  local loop
  loop="$(losetup --show -f "${file}")"
  pvcreate -ff -y "${loop}"
  vgcreate "${vg}" "${loop}"

  # Persist the loop device across reboots
  cat >/etc/systemd/system/"${vg}"-loop.service <<EOF
[Unit]
Description=Loopback for ${vg} VG
DefaultDependencies=no
After=local-fs.target
Before=lvm2-monitor.service

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/sbin/losetup -f ${file}
ExecStop=/sbin/losetup -d ${loop}

[Install]
WantedBy=local-fs.target
EOF
  systemctl daemon-reload
  systemctl enable --now "${vg}"-loop.service >/dev/null
}

setup_storage_vgs() {
  log "Setting up Cinder + Manila LVM volume groups"

  if [[ -n "${CINDER_LVM_DEVICE:-}" ]]; then
    ensure_lvm_vg "${CINDER_VG}" "${CINDER_LVM_DEVICE}"
  else
    warn "CINDER_LVM_DEVICE not set — using a loopback file (${CINDER_LOOP_SIZE})."
    warn "  For production performance, partition the SSD and re-run with"
    warn "  CINDER_LVM_DEVICE=/dev/<part> install.sh"
    ensure_lvm_vg_loopback "${CINDER_VG}" "${CINDER_LOOP_FILE}" "${CINDER_LOOP_SIZE}"
  fi

  ensure_lvm_vg_loopback "${MANILA_VG}" "${MANILA_LOOP_FILE}" "${MANILA_LOOP_SIZE}"
}

ensure_kolla_config_dir() {
  mkdir -p "${KOLLA_CONFIG_DIR}"
  # Mirror per-service overrides into /etc/kolla/config/
  rsync -a --delete "${KOLLA_DIR}/config/" "${KOLLA_CONFIG_DIR}/config/"
  cp -f "${KOLLA_DIR}/globals.yml" "${KOLLA_GLOBALS}"
}

ensure_passwords() {
  if [[ -f "${KOLLA_PASSWORDS}" ]]; then
    log "Reusing existing ${KOLLA_PASSWORDS}"
    return
  fi
  log "Generating kolla passwords.yml"
  cp "${KOLLA_VENV}/share/kolla-ansible/etc_examples/kolla/passwords.yml" "${KOLLA_PASSWORDS}"
  "${KOLLA_VENV}/bin/kolla-genpwd" -p "${KOLLA_PASSWORDS}"
}

validate_vip() {
  local vip
  vip="$(awk '/^kolla_internal_vip_address:/ {gsub(/"/,"",$2); print $2}' "${KOLLA_GLOBALS}")"
  [[ -n "${vip}" ]] || fail "kolla_internal_vip_address missing from globals.yml"

  local host_ip
  host_ip="$(ip -4 -o addr show "$(awk '/^network_interface:/ {gsub(/"/,"",$2); print $2}' "${KOLLA_GLOBALS}")" \
              | awk '{print $4}' | cut -d/ -f1 | head -n1)"
  [[ -n "${host_ip}" ]] || fail "Could not detect IP on network_interface."

  log "Mgmt host IP: ${host_ip} | VIP: ${vip}"

  [[ "${vip}" != "${host_ip}" ]] || fail "VIP (${vip}) must differ from host IP (${host_ip})."

  # Ensure VIP is currently free (best-effort arping)
  if command -v arping >/dev/null 2>&1; then
    if arping -q -c 2 -w 3 -D "${vip}" >/dev/null 2>&1; then
      :
    else
      warn "VIP ${vip} appears to already be in use. Edit globals.yml or proceed at your own risk."
    fi
  fi
}

run_kolla() {
  local cmd="$1"; shift
  log "kolla-ansible ${cmd}"
  (
    cd "${KOLLA_DIR}"
    "${KOLLA_VENV}/bin/kolla-ansible" -i inventory "${cmd}" "$@"
  )
}

main() {
  require_root
  require_ubuntu_2404
  check_kvm

  setup_storage_vgs
  ensure_kolla_config_dir
  ensure_passwords
  validate_vip

  # kolla-ansible needs ansible collections + a few host packages
  log "Installing kolla-ansible Ansible Galaxy deps"
  "${KOLLA_VENV}/bin/kolla-ansible" install-deps

  run_kolla bootstrap-servers
  run_kolla prechecks
  run_kolla deploy
  run_kolla post-deploy

  log "Generating /etc/kolla/admin-openrc.sh"
  # post-deploy already drops it, but ensure perms
  chmod 600 /etc/kolla/admin-openrc.sh || true

  if [[ "${SKIP_AMPHORA:-0}" == "1" ]]; then
    warn "SKIP_AMPHORA=1 set — skipping Octavia amphora image build."
    warn "  Run ${SCRIPT_DIR}/build-amphora.sh later to enable load balancer creation."
  else
    log "Building Octavia amphora image (~10–15 min). Set SKIP_AMPHORA=1 to skip."
    "${SCRIPT_DIR}/build-amphora.sh" || warn "Amphora build failed — re-run build-amphora.sh manually."
  fi

  log "Done. Source the admin credentials with:"
  log "  source /etc/kolla/admin-openrc.sh"
  log "Horizon: http://$(awk '/^kolla_internal_vip_address:/ {gsub(/"/,"",$2); print $2}' "${KOLLA_GLOBALS}")/"
  log "Admin password is in /etc/kolla/admin-openrc.sh (OS_PASSWORD)."
  log "Next: ./configure.sh"
}

main "$@"
