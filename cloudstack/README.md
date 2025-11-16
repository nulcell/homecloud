# CloudStack Installation Scripts

This directory contains scripts for installing and configuring Apache CloudStack on Ubuntu 24.04 (noble) LTS.

These scripts are designed to set up a single-node management server and KVM hypervisor environment with NFS primary and secondary storage.

Based on guides from:

- [Rohit Yadav's CloudStack KVM Guide](https://rohityadav.cloud/blog/cloudstack-kvm/)
- [HackMD Guide](https://hackmd.io/@DaLaw2/HJNA0hSA6)

## Prerequisites

Using the following baselines, update the management.sh and kvm-node.sh to install the cloudstack management server (single node management server):

- Ubuntu 24.04 LTS (noble)
- Apache CloudStack version 4.20.1
- KVM hypervisor for virtualization
- NFS for primary and secondary storage
- Network configuration with DHCP and static IP reservations
- CPU model AMD Ryzen
- Linux bridge networking for Management & KVM nodes - cbr{0-n}
- Properly configured network gateway (10.10.31.254) and subnet (/20) (Note: adjust as per your network requirements)
- Ensure that the management server NIC is configured as eth0 and KVM nodes have eth0 and eth1 for networking.
