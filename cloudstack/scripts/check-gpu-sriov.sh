#!/bin/bash
#
# Check GPU SR-IOV Support
# Tests whether GPUs on the system support SR-IOV for vGPU functionality
#
# Usage: sudo ./check-gpu-sriov.sh

set -e

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}GPU SR-IOV Capability Check${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Check for GPUs
log_info "Detecting GPUs..."
GPU_LIST=$(lspci -nn | grep -E "(VGA compatible controller|3D controller|Display controller)")

if [ -z "$GPU_LIST" ]; then
    log_error "No GPUs detected on this system"
    exit 1
fi

echo "$GPU_LIST"
echo ""

# Check each GPU for SR-IOV support
GPU_COUNT=0
SRIOV_CAPABLE=0

while IFS= read -r gpu_line; do
    GPU_COUNT=$((GPU_COUNT + 1))
    
    # Extract PCI address (format: XX:XX.X)
    PCI_ADDR=$(echo "$gpu_line" | grep -oP '^[0-9a-f]{2}:[0-9a-f]{2}\.[0-9a-f]')
    
    # Extract GPU name/model
    GPU_NAME=$(echo "$gpu_line" | sed 's/^[^ ]* //' | sed 's/\[[^]]*\]//g' | xargs)
    
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    log_info "GPU #$GPU_COUNT: $PCI_ADDR"
    echo "  Model: $GPU_NAME"
    
    # Check for SR-IOV capability in device
    SRIOV_CAP=$(lspci -vvv -s "$PCI_ADDR" 2>/dev/null | grep -i "Single Root I/O Virtualization" || true)
    
    if [ -n "$SRIOV_CAP" ]; then
        log_success "SR-IOV Capability: PRESENT"
        SRIOV_CAPABLE=$((SRIOV_CAPABLE + 1))
        
        # Get Total VFs and Initial VFs
        TOTAL_VFS=$(lspci -vvv -s "$PCI_ADDR" 2>/dev/null | grep "TotalVFs:" | grep -oP 'TotalVFs:\s*\K\d+' || echo "0")
        INITIAL_VFS=$(lspci -vvv -s "$PCI_ADDR" 2>/dev/null | grep "InitialVFs:" | grep -oP 'InitialVFs:\s*\K\d+' || echo "0")
        
        echo "  Total VFs: $TOTAL_VFS"
        echo "  Initial VFs: $INITIAL_VFS"
        
        # Check sysfs for current VF configuration
        if [ -f "/sys/bus/pci/devices/0000:$PCI_ADDR/sriov_totalvfs" ]; then
            SYSFS_TOTAL=$(cat "/sys/bus/pci/devices/0000:$PCI_ADDR/sriov_totalvfs")
            SYSFS_NUMVFS=$(cat "/sys/bus/pci/devices/0000:$PCI_ADDR/sriov_numvfs" 2>/dev/null || echo "0")
            echo "  System Total VFs: $SYSFS_TOTAL"
            echo "  Configured VFs: $SYSFS_NUMVFS"
            
            if [ "$SYSFS_NUMVFS" -gt 0 ]; then
                log_success "SR-IOV is ENABLED with $SYSFS_NUMVFS Virtual Functions"
            else
                log_warn "SR-IOV is DISABLED (can be enabled)"
            fi
        fi
    else
        log_error "SR-IOV Capability: NOT SUPPORTED"
        
        # Check for integrated GPU
        if echo "$GPU_NAME" | grep -qi "integrated\|APU\|Ryzen\|Core"; then
            echo "  Note: Integrated/APU GPUs typically don't support SR-IOV"
        fi
    fi
    
    # Check driver
    DRIVER=$(lspci -k -s "$PCI_ADDR" | grep "Kernel driver in use:" | awk '{print $5}')
    if [ -n "$DRIVER" ]; then
        echo "  Driver: $DRIVER"
    else
        echo "  Driver: None loaded"
    fi
    
    echo ""
done <<< "$GPU_LIST"

# Summary
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Summary${NC}"
echo -e "${BLUE}========================================${NC}"
echo "  Total GPUs: $GPU_COUNT"
echo "  SR-IOV Capable: $SRIOV_CAPABLE"
echo ""

if [ $SRIOV_CAPABLE -eq 0 ]; then
    log_error "No SR-IOV capable GPUs found"
    echo ""
    echo "SR-IOV/vGPU requires enterprise-grade GPUs:"
    echo "  • AMD: Radeon Pro W-series, Instinct MI-series"
    echo "  • NVIDIA: Tesla, A-series, RTX enterprise (with vGPU license)"
    echo "  • Intel: Data Center GPU Flex, Max (limited vGPU support)"
    echo ""
    echo "Your current GPUs support:"
    echo "  ✓ Full GPU Passthrough (1 VM per GPU)"
    echo "  ✗ vGPU/SR-IOV (multiple VMs sharing one GPU)"
else
    log_success "$SRIOV_CAPABLE GPU(s) support SR-IOV!"
    echo ""
    echo "To enable SR-IOV Virtual Functions:"
    echo "  1. Load appropriate vGPU drivers (AMD MxGPU or NVIDIA vGPU)"
    echo "  2. Enable VFs: echo N > /sys/bus/pci/devices/0000:XX:XX.X/sriov_numvfs"
    echo "  3. Configure vGPU profiles in hypervisor"
    echo ""
    log_warn "Note: SR-IOV alone isn't enough - you also need vendor vGPU drivers/licenses"
fi
