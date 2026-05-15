#!/bin/bash
#
# CloudStack KVM GPU Passthrough Setup Script
# Configures integrated GPUs (Intel/AMD) for CloudStack GPU passthrough
# and patches the CloudStack GPU discovery script to detect VGA controllers
#
# Requirements:
# - Ubuntu 24.04 LTS (or compatible)
# - CloudStack Agent installed  
# - Run as root or with sudo
# - IOMMU support enabled in BIOS
#
# Tested with:
# - AMD Barcelo integrated GPU
# - AMD Generic integrated GPUs
#
# Usage: sudo ./kvm-gpu-passthrough.sh

set -e

# Colors
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_section() { echo ""; echo -e "${BLUE}========================================${NC}"; echo -e "${BLUE}$1${NC}"; echo -e "${BLUE}========================================${NC}"; }

if [ "$EUID" -ne 0 ]; then log_error "Please run as root or with sudo"; exit 1; fi

log_section "CloudStack KVM GPU Passthrough Setup"

# Step 1: Detect GPUs
log_section "Step 1: Detecting GPU Devices"
GPU_DEVICES=$(lspci -nn | grep -i vga)
if [ -z "$GPU_DEVICES" ]; then log_error "No VGA/GPU devices found!"; exit 1; fi
echo "$GPU_DEVICES"; echo ""

GPU_IDS=$(lspci -nn | grep -i vga | grep -oP '\[\K[0-9a-f]{4}:[0-9a-f]{4}(?=\])' | tr '\n' ',' | sed 's/,$//')
if [ -z "$GPU_IDS" ]; then log_error "Could not extract GPU IDs"; exit 1; fi
log_info "GPU IDs found: $GPU_IDS"; echo ""

# Step 2: Check IOMMU
log_section "Step 2: Checking IOMMU Support"
if grep -q "intel_iommu=on\|amd_iommu=on" /proc/cmdline; then log_info "IOMMU already enabled"; else log_warn "IOMMU not enabled"; fi

if [ -d "/sys/kernel/iommu_groups" ]; then log_info "IOMMU groups:"; for d in /sys/kernel/iommu_groups/*/devices/*; do if [[ $(basename "$d") == *":"* ]]; then dev=$(basename "$d"); if lspci -s "$dev" | grep -qi "vga\|3d"; then echo "  Group $(basename $(dirname $(dirname "$d")))"; lspci -nns "$dev"; fi; fi; done; echo ""; fi

# Step 3: Kernel params
log_section "Step 3: Configuring Kernel Parameters"
CPU_VENDOR=$(lscpu | grep "Vendor ID:" | head -1 | awk '{print $3}')
log_info "CPU: $CPU_VENDOR"

if [[ "$CPU_VENDOR" == "GenuineIntel" ]]; then IOMMU_PARAMS="intel_iommu=on iommu=pt"
elif [[ "$CPU_VENDOR" == "AuthenticAMD" ]]; then IOMMU_PARAMS="amd_iommu=on iommu=pt"
else log_error "Unknown CPU: $CPU_VENDOR"; exit 1; fi
log_info "IOMMU params: $IOMMU_PARAMS"

GRUB_FILE="/etc/default/grub"
cp "$GRUB_FILE" "${GRUB_FILE}.backup.$(date +%Y%m%d_%H%M%S)"
sed -i.bak "s/GRUB_CMDLINE_LINUX_DEFAULT=\"\(.*\)\"/GRUB_CMDLINE_LINUX_DEFAULT=\"\1 $IOMMU_PARAMS\"/" "$GRUB_FILE"
grep "^GRUB_CMDLINE_LINUX_DEFAULT=" "$GRUB_FILE"; echo ""

# Step 4: VFIO
log_section "Step 4: Configuring VFIO"
cat > /etc/modprobe.d/vfio.conf << EOF
options vfio-pci ids=$GPU_IDS
softdep drm pre: vfio-pci
EOF
cat /etc/modprobe.d/vfio.conf; echo ""

# Step 5: Initramfs
log_section "Step 5: Configuring Initramfs"
MODULES_FILE="/etc/initramfs-tools/modules"
cp "$MODULES_FILE" "${MODULES_FILE}.backup.$(date +%Y%m%d_%H%M%S)"
for mod in vfio vfio_iommu_type1 vfio_pci; do grep -q "^$mod$" "$MODULES_FILE" || echo "$mod" >> "$MODULES_FILE"; done

# Step 6: Blacklist
log_section "Step 6: Blacklisting GPU Drivers"
GPU_VENDOR=$(lspci | grep -i vga | head -1)
if [[ "$GPU_VENDOR" =~ Intel ]]; then DRIVERS="i915"
elif [[ "$GPU_VENDOR" =~ AMD ]]; then DRIVERS="amdgpu radeon"
elif [[ "$GPU_VENDOR" =~ NVIDIA ]]; then DRIVERS="nouveau nvidia"; fi

if [ -n "$DRIVERS" ]; then
    log_info "Blacklisting: $DRIVERS"
    (for d in $DRIVERS; do echo "blacklist $d"; done) > /etc/modprobe.d/blacklist-gpu.conf
    cat /etc/modprobe.d/blacklist-gpu.conf; echo ""
fi

# Step 7: Patch discovery script
log_section "Step 7: Patching CloudStack GPU Discovery"
SCRIPT="/usr/share/cloudstack-common/scripts/vm/hypervisor/kvm/gpudiscovery.sh"
if [ -f "$SCRIPT" ]; then
    cp "$SCRIPT" "${SCRIPT}.backup.$(date +%Y%m%d_%H%M%S)"
    if grep -q "VGA\\\\ compatible\\\\ controller" "$SCRIPT"; then
        log_info "Already patched"
    else
        sed -i 's/(3D\\ controller|Processing\\ accelerators)/(VGA\\ compatible\\ controller|3D\\ controller|Processing\\ accelerators)/g' "$SCRIPT"
        grep -q "VGA\\\\ compatible\\\\ controller" "$SCRIPT" && log_info "✓ Patched" || log_error "Patch failed"
    fi
else log_warn "Script not found"; fi; echo ""

# Step 8: Update
log_section "Step 8: Updating System"
update-grub; update-initramfs -u; echo ""

# Summary
log_section "Setup Complete!"
echo ""; log_info "Summary:"
echo "  CPU: $CPU_VENDOR"
echo "  IOMMU: $IOMMU_PARAMS"
echo "  GPU IDs: $GPU_IDS"
echo "  Drivers blacklisted: ${DRIVERS:-none}"
echo ""; log_warn "REBOOT REQUIRED!"; echo ""
log_info "Verify after reboot:"
echo "  1. dmesg | grep -i iommu"
echo "  2. lspci -nnk | grep -A 3 VGA"
echo "  3. ls -l /dev/vfio/"
echo "  4. sudo $SCRIPT"
echo "  5. CloudStack UI: Host > GPU > Refresh"
echo ""

read -p "Reboot now? (y/n) " -n 1 -r; echo
[[ $REPLY =~ ^[Yy]$ ]] && { log_info "Rebooting..."; sleep 3; reboot; } || log_info "Reboot manually: sudo reboot"
