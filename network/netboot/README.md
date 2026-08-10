# netboot host

**Not deployed.** Notes for a planned Raspberry Pi provisioning host: netboot.xyz over TFTP
plus a dnsmasq ProxyDHCP that hands PXE clients a boot file without owning DHCP leases. The
Pi-hole (DNS + DHCP) and Tailscale halves of that plan are not written up yet.

Replace `10.10.16.136` throughout with the Pi's actual address.

## Installation

```sh
# Install Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh

# Setup directories
mkdir -p ~/netbootxyz/config ~/netbootxyz/assets
cd ~/netbootxyz

# Create Docker Compose file
cat > docker-compose.yml <<'EOF'
services:
  netbootxyz:
    image: ghcr.io/netbootxyz/netbootxyz:latest
    container_name: netbootxyz
    volumes:
      - ./config:/config
      - ./assets:/assets
    ports:
      - 3000:3000    # Web UI
      - 69:69/udp    # TFTP Server
      - 8080:80      # HTTP Asset Server
    restart: unless-stopped

  proxydhcp:
    image: alpine:latest
    container_name: proxydhcp
    network_mode: host
    restart: unless-stopped
    cap_add:
      - NET_ADMIN
    volumes:
      - ./dnsmasq.conf:/etc/dnsmasq.conf:ro
    command: sh -c "apk add --no-cache dnsmasq && dnsmasq -k --user=root"
EOF

# Create dnsmasq configuration
cat > dnsmasq.conf <<'EOF'
# Disable DNS server functionality
port=0

# Log DHCP/PXE interactions for easy troubleshooting
log-dhcp

# Enable ProxyDHCP mode on your network subnet. 
# (Replace 10.10.16.136 with your Raspberry Pi IP)
dhcp-range=10.10.16.136,proxy

# Define PXE boot files based on client architecture
pxe-service=X86PC, "Boot Legacy BIOS", netboot.xyz.kpxe, 10.10.16.136
pxe-service=X86-64_EFI, "Boot UEFI UEFI", netboot.xyz.efi, 10.10.16.136
pxe-service=ARM64_EFI, "Boot ARM64 UEFI", netboot.xyz-arm64.efi, 10.10.16.136
EOF

# Disable conflicting services
sudo systemctl stop systemd-networkd.socket systemd-networkd
sudo systemctl disable systemd-networkd.socket systemd-networkd
sudo systemctl mask systemd-networkd.socket systemd-networkd

# Start the services
sudo docker compose down && sudo docker compose up -d
```
