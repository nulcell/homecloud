#!/bin/bash

set -e

# IP addresses of the NFS disks (replace with your actual IPs)
CONFIG_DISK_IP="10.0.0.45"
DATA_DISK_IP="10.0.0.16"

# This script installs the necessary dependencies for the media server.
sudo apt-get update
sudo apt-get -y full-upgrade
sudo apt install -y tree nfs-common

# mount data disk at /data and config disk at /config
sudo mkdir -p /data
sudo mkdir -p /config
sudo chown -R cloud:cloud /data
sudo chown -R cloud:cloud /config

# Mount the NFS config and data disks
sudo mount -t nfs $CONFIG_DISK_IP:/export /config
sudo mount -t nfs $DATA_DISK_IP:/export /data

# enable automount of /data and /config on boot
echo "$CONFIG_DISK_IP:/export /config nfs defaults 0 0" | sudo tee -a /etc/fstab
echo "$DATA_DISK_IP:/export /data nfs defaults 0 0" | sudo tee -a /etc/fstab

# ### Install docker
# Add Docker's official GPG key:
sudo apt update
sudo apt install ca-certificates curl
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc

# Add the repository to Apt sources:
sudo tee /etc/apt/sources.list.d/docker.sources <<EOF
Types: deb
URIs: https://download.docker.com/linux/ubuntu
Suites: $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}")
Components: stable
Signed-By: /etc/apt/keyrings/docker.asc
EOF

sudo apt update
sudo apt install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
sudo groupadd docker || true
sudo usermod -aG docker $USER
newgrp docker

# # Install AMD GPU drivers (if needed, but not likely) (https://www.amd.com/en/support/download/linux-drivers.html)
# wget https://repo.radeon.com/amdgpu-install/7.1.1/ubuntu/noble/amdgpu-install_7.1.1.70101-1_all.deb
# sudo apt install -y ./amdgpu-install_7.1.1.70101-1_all.deb
# sudo amdgpu-install -y --usecase=graphics,rocm --no-dkms -y --accept-eula
# sudo usermod -a -G render,video $LOGNAME
