# Status: working
#!/bin/bash

set -e

### Notes: 
###   - Designed for Ubuntu 24.04 LTS with CloudStack 4.22
###   - Assumes MaaS is used for metal, network, and DHCP management
###   - Create cloudbr0 bridge via MaaS during commissioning
###   - Ensure MaaS proxy for apt is disabled
###   - This script is not idempotent, meant for one-time setup only

### Tips: 
###   - When rebooting MaaS server, run "sudo snap restart maas" if MAAS services do not come up properly

### Todo:
###   - Modularize script into functions
###   - Add error handling and logging
###   - Validate prerequisites before proceeding
###   - Convert into a CloudStack all-in-one script for single-node, multi-node, high-availability, storage, kvm host, update, etc.

# Variables
CLOUDSTACK_VERSION="4.22"
CLOUDSTACK_DB_USER="cloud"
CLOUDSTACK_DB_PASSWORD="cloud"
MYSQL_DATABASE_HOSTNAME="localhost"
MYSQL_ROOT_PASSWORD=""
CLOUDBR0_IP=$(ip a show cloudbr0 | grep -i "inet " | awk '{print $2}' | cut -d'/' -f1)
MINIO_ROOT_USER="admin"
MINIO_ROOT_PASSWORD="password"



# Introduction
echo "---------------------------------------------------"
echo "CloudStack Management Server Installation Script"
echo "Ubuntu 24.04 LTS - CloudStack ${CLOUDSTACK_VERSION} Single Node Setup with KVM Host and NFS Storage"
echo "---------------------------------------------------"



echo "-> Installing general dependencies..."
apt-get update -y
apt-get full-upgrade -y
apt-get install -y openntpd openssh-server sudo vim htop tar bridge-utils ovmf uuid cloud-init wget cloud-initramfs-growroot
if grep -q 'GenuineIntel' /proc/cpuinfo; then
    apt-get install -y intel-microcode
elif grep -q 'AuthenticAMD' /proc/cpuinfo; then
    apt-get install -y amd64-microcode mesa-utils
fi
echo "-> Dependencies Installed."



echo "-> Configuring CloudStack APT Repository..."
mkdir -p /etc/apt/keyrings
wget -qO - http://download.cloudstack.org/release.asc | gpg --dearmor | tee /etc/apt/keyrings/cloudstack.gpg > /dev/null
echo "deb [signed-by=/etc/apt/keyrings/cloudstack.gpg] http://download.cloudstack.org/ubuntu noble $CLOUDSTACK_VERSION" > /etc/apt/sources.list.d/cloudstack.list
apt-get update -y
echo "-> CloudStack APT Repository Configured."



echo "-> Starting CloudStack Management Server installation..."
apt-get update -y
apt-get install -y cloudstack-management cloudstack-usage mysql-server
cat >> /etc/mysql/mysql.conf.d/mysqld.cnf << EOF
server_id = 1
sql-mode="STRICT_TRANS_TABLES,NO_ENGINE_SUBSTITUTION,ERROR_FOR_DIVISION_BY_ZERO,NO_ZERO_DATE,NO_ZERO_IN_DATE,NO_ENGINE_SUBSTITUTION"
innodb_rollback_on_timeout=1
innodb_lock_wait_timeout=600
max_connections=1000
log-bin=mysql-bin
binlog-format = 'ROW'
EOF
systemctl restart mysql
cloudstack-setup-databases $CLOUDSTACK_DB_USER:$CLOUDSTACK_DB_PASSWORD@$MYSQL_DATABASE_HOSTNAME --deploy-as=root:$MYSQL_ROOT_PASSWORD -i $CLOUDBR0_IP
echo "-> CloudStack Management Server installation completed."



echo "-> Configure NFS Server..."
apt-get install -y nfs-kernel-server quota
echo "/export  *(rw,async,no_root_squash,no_subtree_check)" > /etc/exports
mkdir -p /export/primary /export/secondary
exportfs -a
sed -i -e 's/^RPCMOUNTDOPTS="--manage-gids"$/RPCMOUNTDOPTS="-p 892 --manage-gids"/g' /etc/default/nfs-kernel-server
sed -i -e 's/^STATDOPTS=$/STATDOPTS="--port 662 --outgoing-port 2020"/g' /etc/default/nfs-common
echo "NEED_STATD=yes" >> /etc/default/nfs-common
sed -i -e 's/^RPCRQUOTADOPTS=$/RPCRQUOTADOPTS="-p 875"/g' /etc/default/quota
service nfs-kernel-server restart
echo "-> NFS Server configured."



echo "-> Configuring KVM Host..."
apt-get -y install qemu-kvm cloudstack-agent
sed -i -e 's/\#vnc_listen.*$/vnc_listen = "0.0.0.0"/g' /etc/libvirt/qemu.conf
systemctl mask libvirtd.socket libvirtd-ro.socket libvirtd-admin.socket libvirtd-tls.socket libvirtd-tcp.socket
# systemctl restart libvirtd
echo 'remote_mode="legacy"' >> /etc/libvirt/libvirt.conf
echo 'listen_tls=0' >> /etc/libvirt/libvirtd.conf
echo 'listen_tcp=1' >> /etc/libvirt/libvirtd.conf
echo 'tcp_port = "16509"' >> /etc/libvirt/libvirtd.conf
echo 'mdns_adv = 0' >> /etc/libvirt/libvirtd.conf
echo 'auth_tcp = "none"' >> /etc/libvirt/libvirtd.conf
# systemctl restart libvirtd
echo "net.bridge.bridge-nf-call-arptables = 0" >> /etc/sysctl.conf
echo "net.bridge.bridge-nf-call-iptables = 0" >> /etc/sysctl.conf
echo "net.bridge.bridge-nf-call-ip6tables = 0" >> /etc/sysctl.conf
sysctl -p
UUID=$(uuid)
echo host_uuid = \"$UUID\" >> /etc/libvirt/libvirtd.conf
systemctl restart libvirtd
# Enable UEFI support in CloudStack Agent
cat >> /etc/cloudstack/agent/uefi.properties << EOF
guest.nvram.template.secure=/usr/share/OVMF/OVMF_VARS_4M.ms.fd
guest.nvram.template.legacy=/usr/share/OVMF/OVMF_4M.fd
guest.nvram.path=/var/lib/libvirt/qemu/nvram/
guest.loader.secure=/usr/share/OVMF/OVMF_CODE_4M.secboot.fd
guest.loader.legacy=/usr/share/OVMF/OVMF_CODE_4M.fd
EOF
# Configure firewall
if ! ufw status | grep -q inactive; then
    ufw allow mysql
    ufw allow proto tcp from any to any port 22
    ufw allow proto tcp from any to any port 1798
    ufw allow proto tcp from any to any port 16509
    ufw allow proto tcp from any to any port 16514
    ufw allow proto tcp from any to any port 5900:6100
    ufw allow proto tcp from any to any port 49152:49216
fi
# Disable apparmour on libvirtd
ln -s /etc/apparmor.d/usr.sbin.libvirtd /etc/apparmor.d/disable/
ln -s /etc/apparmor.d/usr.lib.libvirt.virt-aa-helper /etc/apparmor.d/disable/
apparmor_parser -R /etc/apparmor.d/usr.sbin.libvirtd
apparmor_parser -R /etc/apparmor.d/usr.lib.libvirt.virt-aa-helper
systemctl restart cloudstack-agent
echo "-> KVM Host configured."



echo "-> Starting CloudStack Management Server..."
cloudstack-setup-management
systemctl status cloudstack-management --no-pager
echo "-> CloudStack Management Server started."



echo "-> Configuring Root User..."
echo "Waiting until SSH keys are generated..."
while [ ! -f /var/lib/cloudstack/management/.ssh/id_rsa.pub ]; do
    sleep 2
done
echo "SSH keys found. Configuring root user..."
mkdir -p /root/.ssh
echo "Cleaning root blocker commands in authorized_keys..."
sed '1s/.*exit 142" //' /root/.ssh/authorized_keys > /root/.ssh/authorized_keys.tmp
mv /root/.ssh/authorized_keys.tmp /root/.ssh/authorized_keys
cat /var/lib/cloudstack/management/.ssh/id_rsa.pub >> /root/.ssh/authorized_keys
echo "-> Root User configured."



echo "-> Installing MinIO for Object Storage..."
wget https://dl.min.io/server/minio/release/linux-amd64/minio -O /usr/local/bin/minio
groupadd -r minio-user
useradd -M -r -g minio-user minio-user
mkdir -p /minio/data
chown minio-user:minio-user /minio/data
chmod u+rxw /minio/ /usr/local/bin/minio
chown -R minio-user /minio/ /usr/local/bin/minio
cat > /etc/systemd/system/minio.service << EOF
[Unit]
Description=MinIO High Performance Object Storage
Documentation=https://docs.min.io
Wants=network-online.target
After=network-online.target

[Service]
User=minio-user
Group=minio-user
WorkingDirectory=/minio/data
ExecStart=/usr/local/bin/minio server /minio/data --console-address ":9001"
Restart=always
RestartSec=5

# Set environment variables
Environment="MINIO_ROOT_USER=${MINIO_ROOT_USER}"
Environment="MINIO_ROOT_PASSWORD=${MINIO_ROOT_PASSWORD}"

# Allow MinIO to bind to low ports if needed
CapabilityBoundingSet=CAP_NET_BIND_SERVICE
AmbientCapabilities=CAP_NET_BIND_SERVICE
NoNewPrivileges=true

[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload
systemctl start minio
systemctl enable minio
systemctl status minio --no-pager
echo "-> MinIO installed and running."



echo "\n\nCloudStack Management Server installation completed!"
echo "Management Server IP: ${CLOUDBR0_IP}"
echo "NFS Primary Storage: /export/primary"
echo "NFS Secondary Storage: /export/secondary"
echo ""
echo "Next Steps:"
echo "1. Access the CloudStack Management UI at http://${CLOUDBR0_IP}:8080/client"
echo "2. Login with default credentials: admin/password"
echo "3. Change the admin password immediately after logging in."
echo "4. Create a Zone, Pod, Cluster, add this KVM Host, and finally create primary and secondary storage."
echo "5. Configure Primary and Secondary Storage using the NFS paths provided above."
echo "6. Use simple VLAN config with vlan://untagged for network setup."
echo "7. Restart the CloudStack Management service if needed: sudo systemctl restart cloudstack-management"
echo "8. Run the following after onboarding any host to support UEFI VMs:"
echo "   $ systemctl unmask libvirtd.socket libvirtd-ro.socket libvirtd-admin.socket libvirtd-tls.socket libvirtd-tcp.socket"
echo "   $ systemctl stop libvirtd; systemctl start libvirtd-tls.socket; systemctl enable libvirtd-tls.socket"
echo "   $ reboot now"
echo "9. Enjoy your CloudStack environment!"
echo ""
