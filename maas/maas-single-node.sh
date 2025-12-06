#!/bin/bash

set -e

### Notes:
###   - Ironically, this script sets up a single-node MAAS server on Ubuntu 24.04 LTS and is expected to be run by MAAS itself running on a VM for inital setup or you can also manually install Ubuntu 24.04 LTS on a physical server and run this script to turn it into a MAAS server
###   - If you need to install raspbian first (if using a Raspberry Pi) you can do this via the cli by runnging:
###       - $ wget https://downloads.raspberrypi.com/raspios_lite_arm64/images/raspios_lite_arm64-2025-10-02/2025-10-01-raspios-trixie-arm64-lite.img.xz
###       - $ xzcat 2025-10-01-raspios-trixie-arm64-lite.img.xz | sudo dd of=/dev/sda bs=4M status=progress; sync
###   - If you need to install Ubuntu Server 20.04 LTS on ARM first you can do this via the cli by runnging (using Raspberry Pi as an example):
###       - $ wget https://cdimage.ubuntu.com/releases/24.04/release/ubuntu-24.04.3-preinstalled-server-arm64+raspi.img.xz
###       - $ xzcat ubuntu-24.04.3-preinstalled-server-arm64+raspi.img.xz | sudo dd of=/dev/sda bs=4M status=progress; sync
###       - $ echo "username: ubuntu; password: ubuntu"
###   - This script is not idempotent, meant for one-time setup only
###   - Guide: https://canonical.com/maas/docs/how-to-get-maas-up-and-running
###   - DHCP configure fix: https://askubuntu.com/a/850313

### Tips:
###   - After running this script, access the MAAS web UI at http://<MAAS_SERVER_IP>:5240/MAAS to complete the setup and configure MAAS
###   - Make sure the MAAS server has a static IP address and proper DNS settings

### Todo:
###   - Modularize script into functions
###   - Add error handling and logging
###   - Validate prerequisites before proceeding
###   - Automate MAAS web UI initial configuration via API calls

# Variables
MAAS_VERSION="3.6"
MAAS_ADMIN_USERNAME="admin"
MAAS_ADMIN_PASSWORD="adminpassword"
MAAS_ADMIN_EMAIL="admin@example.com"
SERVER_IP=$(hostname -I | awk '{print $1}')

# Introduction
echo "---------------------------------------------------"
echo "MAAS Single Node Installation Script"
echo "Ubuntu 24.04 LTS - MAAS ${MAAS_VERSION} Single Node Setup"
echo "---------------------------------------------------"

echo "-> Checking for root privileges..."
if [ "$EUID" -ne 0 ]; then
  echo "Please run as root."
  exit 1
fi
echo "-> Root privileges confirmed."

echo "-> Installing MaaS..."
apt-get update -y
apt-get full-upgrade -y
apt-add-repository ppa:maas/$MAAS_VERSION -y
apt-get update -y
apt -y install maas mkcert
echo "-> MaaS Installed."

echo "-> Initializing MaaS..."
maas createadmin --username=$MAAS_ADMIN_USERNAME --password=$MAAS_ADMIN_PASSWORD --email=$MAAS_ADMIN_EMAIL
echo "-> MaaS Initialized."

echo "-> MAAS Single Node Installation Completed."
echo "->   - HTTP Web UI: http://$SERVER_IP:5443/MAAS or http://$(hostname):5443/MAAS"
echo "->   - Admin Credentials:"
echo "->   - Username: $MAAS_ADMIN_USERNAME"
echo "->   - Password: $MAAS_ADMIN_PASSWORD"
echo "->   - CLI Login: maas login local http://localhost:5240/MAAS/ <api-key>"
echo "---------------------------------------------------"
