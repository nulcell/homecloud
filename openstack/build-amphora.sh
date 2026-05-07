#!/usr/bin/env bash
# Build the Octavia amphora qcow2 image and upload it to Glance with tag
# "amphora" so Octavia can spawn LB amphorae from it.
#
# Octavia auto_configure handles networks/flavors/certs but does NOT build the
# amphora image — that's intentionally left to the operator since the image
# embeds your distro/HAProxy preference. This script uses the upstream octavia
# diskimage-create.sh to produce a Ubuntu 24.04 + HAProxy qcow2 (~250MB).
#
# Usage:
#   sudo -E ./build-amphora.sh           # build + upload (default)
#   ./build-amphora.sh --upload-only     # skip build, upload existing qcow2
#
# Environment overrides:
#   AMPHORA_DIST     debian|ubuntu|centos|fedora        (default: ubuntu)
#   AMPHORA_RELEASE  noble|jammy|bookworm|...           (default: noble)
#   AMPHORA_OUT      output qcow2 path                  (default: /var/lib/octavia/amphora-x64-haproxy.qcow2)
#   OCTAVIA_REF      git ref of openstack/octavia repo  (default: stable/2025.1)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ADMIN_OPENRC="/etc/kolla/admin-openrc.sh"
KOLLA_VENV="${KOLLA_VENV:-/opt/kolla/venv}"

AMPHORA_DIST="${AMPHORA_DIST:-ubuntu}"
AMPHORA_RELEASE="${AMPHORA_RELEASE:-noble}"
AMPHORA_OUT="${AMPHORA_OUT:-/var/lib/octavia/amphora-x64-haproxy.qcow2}"
OCTAVIA_REF="${OCTAVIA_REF:-stable/2025.1}"
OCTAVIA_REPO_DIR="${OCTAVIA_REPO_DIR:-/opt/octavia-builder}"

UPLOAD_ONLY=0
[[ "${1:-}" == "--upload-only" ]] && UPLOAD_ONLY=1

log()  { printf "\033[1;34m[amphora]\033[0m %s\n" "$*"; }
warn() { printf "\033[1;33m[amphora]\033[0m %s\n" "$*" >&2; }
fail() { printf "\033[1;31m[amphora]\033[0m %s\n" "$*" >&2; exit 1; }

OS() {
  if [[ -x "${KOLLA_VENV}/bin/openstack" ]]; then
    "${KOLLA_VENV}/bin/openstack" "$@"
  else
    openstack "$@"
  fi
}

build_image() {
  [[ $EUID -eq 0 ]] || fail "Build requires root (sudo -E)."

  log "Installing diskimage-builder host deps"
  apt-get update -qq
  apt-get install -y --no-install-recommends \
    git qemu-utils kpartx debootstrap python3-pip \
    cloud-utils-euca uuid-runtime >/dev/null

  if [[ ! -d "${OCTAVIA_REPO_DIR}/.git" ]]; then
    log "Cloning openstack/octavia (${OCTAVIA_REF}) → ${OCTAVIA_REPO_DIR}"
    git clone --depth 1 --branch "${OCTAVIA_REF}" \
      https://opendev.org/openstack/octavia.git "${OCTAVIA_REPO_DIR}"
  else
    log "Updating ${OCTAVIA_REPO_DIR}"
    git -C "${OCTAVIA_REPO_DIR}" fetch --depth 1 origin "${OCTAVIA_REF}"
    git -C "${OCTAVIA_REPO_DIR}" reset --hard "FETCH_HEAD"
  fi

  # Octavia diskimage-create.sh reads its own python deps via pip.
  log "Installing diskimage-builder into ${KOLLA_VENV}"
  "${KOLLA_VENV}/bin/pip" install --upgrade diskimage-builder >/dev/null

  mkdir -p "$(dirname "${AMPHORA_OUT}")"

  log "Building amphora qcow2 (dist=${AMPHORA_DIST}, release=${AMPHORA_RELEASE})"
  log "  This typically takes 10–15 minutes."
  (
    cd "${OCTAVIA_REPO_DIR}/diskimage-create"
    PATH="${KOLLA_VENV}/bin:${PATH}" \
      ./diskimage-create.sh \
      -i "${AMPHORA_DIST}" \
      -d "${AMPHORA_RELEASE}" \
      -o "${AMPHORA_OUT}"
  )

  [[ -f "${AMPHORA_OUT}" ]] || fail "Build did not produce ${AMPHORA_OUT}"
  log "Built: ${AMPHORA_OUT} ($(du -h "${AMPHORA_OUT}" | cut -f1))"
}

upload_image() {
  [[ -f "${ADMIN_OPENRC}" ]] || fail "Missing ${ADMIN_OPENRC}. Run install.sh first."
  # shellcheck disable=SC1090
  source "${ADMIN_OPENRC}"

  [[ -f "${AMPHORA_OUT}" ]] || fail "Image not found: ${AMPHORA_OUT}"

  # The 'service' project owns Octavia's resources. amphora image must live there.
  local service_project_id
  service_project_id="$(OS project show service -f value -c id)"

  if OS image list --project "${service_project_id}" --tag amphora -f value -c Name | grep -q .; then
    log "Existing amphora-tagged image(s) found in service project — uploading new revision"
  fi

  local image_name
  image_name="amphora-${AMPHORA_DIST}-${AMPHORA_RELEASE}-$(date +%Y%m%d-%H%M%S)"
  log "Uploading ${image_name} to glance (project=service, tag=amphora)"
  OS image create "${image_name}" \
    --container-format bare \
    --disk-format qcow2 \
    --private \
    --project "${service_project_id}" \
    --tag amphora \
    --property hw_architecture=x86_64 \
    --property hw_rng_model=virtio \
    --file "${AMPHORA_OUT}"

  log "Done. Octavia will pick this up on next LB create."
  log "If Octavia services were already running, restart octavia_worker to flush its image cache:"
  log "  docker restart octavia_worker octavia_health_manager octavia_housekeeping"
}

main() {
  if (( UPLOAD_ONLY == 0 )); then
    build_image
  fi
  upload_image
}

main "$@"
