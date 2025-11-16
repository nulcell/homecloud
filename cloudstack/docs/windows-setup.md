# Guide for Setting Up Windows VMs in CloudStack

This document provides a comprehensive guide for setting up Windows virtual machines (VMs) in Apache CloudStack. It covers the necessary steps to create, configure, and manage Windows VMs effectively.

## Prerequisites

Before you begin, ensure you have the following prerequisites in place:

- An Apache CloudStack environment with administrative access.
- A Windows ISO image uploaded to the CloudStack template library.
- Sufficient resources (CPU, RAM, storage) in your CloudStack environment to host the Windows VM.
- A valid Windows license key for activation. (or use KMS for volume licensing)

## Steps to Set Up Windows VMs

1. **Create a Windows VM Template**:
    - Upload the Windows ISO image to the CloudStack template library with the appropriate OS type and version.
    - Set the following parameters during the upload:
        - Bootable: Yes
        - OS Type: Windows 11 64-bit
        - Dynamically scalable: No
        - Extractable: No
        - Public: Yes
        - Featured: Yes
        - Password enabled: No
2. **Create an ISO Template for VirtIO Windows Drivers**:
    - Download the latest VirtIO Windows drivers ISO from [Fedora People](https://fedorapeople.org/groups/virt/virtio-win/direct-downloads/stable-virtio/virtio-win.iso).
    - Upload the VirtIO ISO to the CloudStack template library with the following parameters:
        - Bootable: No
        - Dynamically scalable: No
        - Extractable: No
        - Public: Yes
        - Featured: No
        - Password enabled: No
3. **Deploy the Windows VM**:
    - Navigate to the "Instances" section in the CloudStack UI.
    - Click on "Add Instance" and select the Windows VM template created in step 1
    - Configure the VM settings (Hypervisor, Compute offering (minimum 2 vCPU and 4GB RAM recommended), Disk offering, Network, etc.).
    - In the "Advanced Mode", set the following:
        - Boot type: UEFI
        - Boot mode: SECURE
    - Disable "Start Instance"
    - Review options and click "Create Instance".
4. **Update Instance Settings**:
    - Once the VM is created, navigate to the "Instances" section and select the newly created Windows VM.
    - Click on "Settings" and then add the following:
        - keyboard: us
        - UEFI: SECURE
        - virtual.tpm.version: 2.0
        - guest.cpu.mode: host-passthrough
        - virtual.tpm.model: tpm-crb
        - nicAdapter: rtl8139
        - rootDiskController: scsi
    - Start the instance.
5. **Install Windows OS**:
    - Access the VM console via the CloudStack UI.
    - Follow the Windows installation prompts to install the OS.
    - Once Windows is installed, go back to the CloudStack UI and detach the Windows ISO from the VM then attach the VirtIO ISO.
    - In the Windows instance, run the VirtIO driver installer from the VirtIO ISO to install necessary drivers for optimal performance.
    - Detach the VirtIO ISO after installation.
6. **Post-Installation Configuration**:
    - Configure Windows RDP settings to allow remote access.
    - Follow the steps on [StackOverflow](https://superuser.com/questions/1715525/how-to-login-windows-remote-desktop-rdp-in-windows-11-when-microsoft-account-a) to set up RDP with a Microsoft account.
        - Run the following command in PowerShell, `irm https://get.activated.win | iex` and select option 1.
    - Activate Windows using [Microsoft Activation Scripts](https://massgrave.dev/)
    - Install any additional software or updates as needed.
