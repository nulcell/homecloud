# Status: working
#!/bin/bash

echo "Trying to fetch metadata URL from CloudStack metadata service..."
ROUTER_IP=$(cat /var/lib/dhcp/dhclient.leases 2>/dev/null | grep dhcp-server-identifier | tail -1 | awk '{print $3}' | cut -d';' -f1)
if [ -z "${ROUTER_IP}" ]; then
  echo "Could not determine router IP from dhclient leases."
  echo "Trying to fetch router IP from tracepath..."
  ROUTER_IP=$(tracepath -n -m1 8.8.8.8 2>/dev/null | grep -oP '1:\s+(\d{1,3}\.){3}\d{1,3}' | awk '{print $2}' | head -1)
fi
if [ -z "${ROUTER_IP}" ]; then
  echo "Could not determine router IP from tracepath."
  echo "Trying to fetch router IP from traceoute..."
  ROUTER_IP=$(traceroute 8.8.8.8 | awk 'NR==2 {print $2}' 2>/dev/null)
fi
if [ -z "${ROUTER_IP}" ]; then
  echo "Could not determine router IP from DHCP leases."
  echo "Trying to fetch router IP from default gateway..."
  ROUTER_IP=$(ip route show | awk '/default/ {print $3}' 2>/dev/null)
fi
if [ -z "${ROUTER_IP}" ]; then
  echo "Could not determine router IP from default gateway."
  echo "Exiting."
  exit 1
fi

METADATA_URL="http://${ROUTER_IP}/latest/meta-data/"
echo "${METADATA_URL}"
