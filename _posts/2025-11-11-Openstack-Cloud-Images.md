---
title: Openstack Cloud Images
description: Walkthrough of the process to import Cloud Images to Openstack.
layout: post
author_profile: true
author: Ciro Iriarte
categories:
- Datacenter
tags:
- Virtualization
- Openstack
---

Once you have your shiny Openstack environment up & running you would like to inmediately start provisioning virtual machines. The starting point are OS images that will provide the base copy of Operating System to use for your new virtual machines.

Images include both the OS disk data and what would normally be virtual machine properties in other virtualization platforms.

I'll provide here a procedure to prepare production grade images coming from the usual Linux Distribution providers.

<!--more-->

# Cloud Images

Enter ["Cloud Images"](https://docs.openstack.org/image-guide/obtain-images.html). These OS images are basically instances prepared/curated by the different Linux distribution projects (or companies) ready to boot in a cloud environment (AWS, Azure, GCP, Openstack, etc). You can treat them as secure as the ISO installer you download for your favorite distribution project, they have a minimal footprint and usually include cloud-init to automate the deployment process.

In Openstack, cloud-init is critical for deployment as you don't want to resize your boot disk, add users or setup TCP/IP by hand. Also QEMU Guest Agent is highly recommended when virtualizing on KVM to enable consistent backups & allow for some operational inventory automation.

Paid Linux distributions (like SLES or RHEL) also provide cloud images. I can't seem to find a Windows Server 2025 Cloud image to download (shame on you Microsoft!).

# Configuration

Actual virtual machine definition needs to be set as properties during the disk image import process. We'll be defining them as that is not part of the Cloud Images files you download.

Some attributes I'm proposing here provide proper documentation (name, version, licensing, etc), others provide performance best practices (machine type, NIC/HBA types) or provide operational best practices (backup related parameters).

# Disk format

In my case, I'm using Ceph RBD as backend for Cinder. If you tell Cinder/Nova to create a volume from a qcow2 image it is going to first download the image, convert it to raw then re-upload it to Ceph. This consumes a lot more space in Ceph, more network bandwidth and is prone to timeouts if conversion and upload takes too long.

If you're using a filesystem backend go with QCOW2 but if you're using Ceph RBD like me, go with RAW in order to benefit from Copy-on-Write cloning of images in both Cinder and Nova & quicker instantiation times.
 

# Tooling

Depending on the machine you're working on, install guestfs-tools. This will allow us to customize the image.

openSUSE:

{% highlight shell %}
sudo zypper install -y guestfs-tools
{% endhighlight %}

Ubuntu:

{% highlight shell %}
sudo apt install -y libguestfs-tools whois
{% endhighlight %}

# Free Images

Find a spot to download files

{% highlight shell %}
mkdir cloud-images
cd cloud-images
{% endhighlight %}
	
## openSUSE

My personal favorite, we'll download Leap which is very similar to SLES (the commercial version of the distribution). Other alternatives are Tumbleweed (bleeding edge) or Slowroll ("I want something newer, but don't get crazy").

It already supports cloud-init, we just enable support for the PTP device to be used by chrony as time reference. The KVM host basically provides it for the guests to [sync time](https://www.libertysys.com.au/2024/04/vm-timekeeping-using-the-ptp-hardware-clock-on-kvm/) and contrary to what happens with VMware Guest Tools, QEMU Guest Agent doesn't provide time sincronization capabilities.

{% highlight shell %}
# Some helper variables
IMG=Leap-16.0-Minimal-VM.x86_64-Cloud.qcow2
IMGRAW="${IMG%.qcow2}.raw"
NAME=ci-opensuse-leap-16.0-x86_64-$(date '+%Y%m%d.%H%M')

# Download the official image
wget https://download.opensuse.org/repositories/openSUSE:/Leap:/16.0:/Images/images/${IMG}

# Fix PTP synchronization
echo ptp_kvm > /tmp/ptp_kvm.conf
sudo virt-customize -a ${IMG} --copy-in /tmp/ptp_kvm.conf:/etc/modules-load.d/

# Convert to RAW
qemu-img convert -f qcow2 -O raw ${IMG} ${IMGRAW}

# Import
openstack image create \
--disk-format raw --container-format bare \
--progress \
--property os_type='linux' \
--property os_distro='opensuse' \
--property os_version='16.0' \
--property os_license=opensource \
--property os_admin_user='opensuse' \
--property hw_qemu_guest_agent=true \
--property os_require_quiesce=true \
--property hw_require_fsfreeze=true \
--property hw_machine_type="q35" \
--property hw_firmware_type=uefi \
--property hw_serial_port_count=1 \
--property hw_vif_model=virtio \
--property hw_vif_multiqueue_enabled=true \
--property hw_virtio_packed_ring=true \
--property hw_scsi_model=virtio-scsi \
--property hw_disk_bus=scsi \
--property hw_video_model=virtio \
--property has_auto_disk_config=true \
--property description="openSUSE Leap 16.0 - Cloud Image" \
--public --file ${IMGRAW} \
${NAME}
{% endhighlight %}


## Rocky Linux

Usual tool for the CentOS refugees. Cloud-init is available out of the box. 

### LVM based image

In case you want to have all your filesystems under LVM management, the project provides a specific image. Only drawback is that cloud-init filesystem resize won't work and manual maneuvering will be required (don't expect hardcore Linux users to have a problem with that).

{% highlight shell %}
# Some helper variables
IMG=Rocky-9-GenericCloud-LVM.latest.x86_64.qcow2 
IMGRAW="${IMG%.qcow2}.raw"
NAME=ci-rocky-9-lvm-x86_64-$(date '+%Y%m%d.%H%M')

# Download the official image
wget https://dl.rockylinux.org/pub/rocky/9/images/x86_64/${IMG}

# Convert to RAW
qemu-img convert -f qcow2 -O raw ${IMG} ${IMGRAW}

# Import
openstack image create \
--disk-format raw --container-format bare \
--progress \
--property os_type='linux' \
--property os_distro='rocky' \
--property os_version='9.6' \
--property os_license=opensource \
--property os_admin_user='rocky' \
--property hw_qemu_guest_agent=true \
--property os_require_quiesce=true \
--property hw_require_fsfreeze=true \
--property hw_machine_type="q35" \
--property hw_firmware_type=uefi \
--property hw_serial_port_count=1 \
--property hw_vif_model=virtio \
--property hw_vif_multiqueue_enabled=true \
--property hw_virtio_packed_ring=true \
--property hw_scsi_model=virtio-scsi \
--property hw_disk_bus=scsi \
--property hw_video_model=virtio \
--property has_auto_disk_config=false \
--property description="Rocky Linux 9.6 with LVM - Cloud Image" \
--public --file ${IMGRAW} \
${NAME}
{% endhighlight %}


### Bare partitions image

This image has bare partitions for operating system filesystems. As with any other Linux image, you can still use LVM for data disks (and probably you should, since hot migration between Ceph pools is not supported by Openstack and LVM-in-guest can save the day when data relocation is required)

{% highlight shell %}
# Some helper variables
IMG=Rocky-9-GenericCloud-Base.latest.x86_64.qcow2 
IMGRAW="${IMG%.qcow2}.raw"
NAME=ci-rocky-9-x86_64-$(date '+%Y%m%d.%H%M')

# Download the official image
wget https://dl.rockylinux.org/pub/rocky/9/images/x86_64/${IMG}

# Convert to RAW
qemu-img convert -f qcow2 -O raw ${IMG} ${IMGRAW}

# Import
openstack image create \
--disk-format raw --container-format bare \
--progress \
--property os_type='linux' \
--property os_distro='rocky' \
--property os_version='9.6' \
--property os_license=opensource \
--property os_admin_user='rocky' \
--property hw_qemu_guest_agent=true \
--property os_require_quiesce=true \
--property hw_require_fsfreeze=true \
--property hw_machine_type="q35" \
--property hw_firmware_type=uefi \
--property hw_serial_port_count=1 \
--property hw_vif_model=virtio \
--property hw_vif_multiqueue_enabled=true \
--property hw_virtio_packed_ring=true \
--property hw_scsi_model=virtio-scsi \
--property hw_disk_bus=scsi \
--property hw_video_model=virtio \
--property has_auto_disk_config=false \
--property description="Rocky Linux 9.6 - Cloud Image" \
--public --file ${IMGRAW} \
${NAME}
{% endhighlight %}

## Oracle Enterprise Linux 9

This is an odd one and I've never been a fan. Another RHEL clone with unfair advantages regarding the made-up Oracle licensing rules. Similarly to Ubuntu, you can pay for support or not. Repositories are public.

{% highlight shell %}
# Some helper variables
IMG=OL9U5_x86_64-kvm-b259.qcow2
IMGRAW="${IMG%.qcow2}.raw"
NAME=ci-oel-9.5-x86_64-$(date '+%Y%m%d.%H%M')

# Download the official image
wget https://yum.oracle.com/templates/OracleLinux/OL9/u5/x86_64/${IMG}

# Convert to RAW
qemu-img convert -f qcow2 -O raw ${IMG} ${IMGRAW}

# Import
openstack image create \
--disk-format raw --container-format bare \
--progress \
--property os_type='linux' \
--property os_distro='oel' \
--property os_version='9.5' \
--property os_license=opensource \
--property os_admin_user='oracle' \
--property hw_qemu_guest_agent=true \
--property os_require_quiesce=true \
--property hw_require_fsfreeze=true \
--property hw_machine_type="q35" \
--property hw_firmware_type=uefi \
--property hw_serial_port_count=1 \
--property hw_vif_model=virtio \
--property hw_vif_multiqueue_enabled=true \
--property hw_virtio_packed_ring=true \
--property hw_scsi_model=virtio-scsi \
--property hw_disk_bus=scsi \
--property hw_video_model=virtio \
--property has_auto_disk_config=false \
--property description="Oracle Enterprise Linux 9.5 - Cloud Image" \
--public --file ${IMGRAW} \
${NAME}
{% endhighlight %}

## Ubuntu 24.04

Ubiquitous distribution, if you like Debian you'll feel at home.

{% highlight shell %}
# Some helper variables
IMG=noble-server-cloudimg-amd64.img
IMGRAW="${IMG%.qcow2}.raw"
NAME=ci-ubuntu-24.04.3-x86_64-$(date '+%Y%m%d.%H%M')

# Download the official image
wget https://cloud-images.ubuntu.com/noble/current/${IMG}

# Install QEMU Guest Agent
sudo virt-customize -a ${IMG} --install qemu-guest-agent

# Convert to RAW
qemu-img convert -f qcow2 -O raw ${IMG} ${IMGRAW}

# Import
openstack image create \
--disk-format raw --container-format bare \
--progress \
--property os_type='linux' \
--property os_distro='ubuntu' \
--property os_version='24.04.3' \
--property os_license=opensource \
--property os_admin_user='ubuntu' \
--property hw_qemu_guest_agent=true \
--property os_require_quiesce=true \
--property hw_require_fsfreeze=true \
--property hw_machine_type="q35" \
--property hw_firmware_type=uefi \
--property hw_serial_port_count=1 \
--property hw_vif_model=virtio \
--property hw_vif_multiqueue_enabled=true \
--property hw_virtio_packed_ring=true \
--property hw_scsi_model=virtio-scsi \
--property hw_disk_bus=scsi \
--property hw_video_model=virtio \
--property has_auto_disk_config=true \
--property description="Ubuntu 24.04.3 (Noble) - Cloud Image" \
--public --file ${IMGRAW} \
${NAME}
{% endhighlight %}

## Ubuntu 22.04

Older & still used version of Ubuntu.

{% highlight shell %}
# Some helper variables
IMG=jammy-server-cloudimg-amd64.img
IMGRAW="${IMG%.qcow2}.raw"
NAME=ci-ubuntu-22.04.5-x86_64-$(date '+%Y%m%d.%H%M')

# Download the official image
wget https://cloud-images.ubuntu.com/jammy/current/${IMG}
sudo virt-customize -a ${IMG} --install qemu-guest-agent

# Convert to RAW
qemu-img convert -f qcow2 -O raw ${IMG} ${IMGRAW}

# Import
openstack image create \
--disk-format raw --container-format bare \
--progress \
--property os_type='linux' \
--property os_distro='ubuntu' \
--property os_version='22.04.5' \
--property os_license=opensource \
--property os_admin_user='ubuntu' \
--property hw_qemu_guest_agent=true \
--property os_require_quiesce=true \
--property hw_require_fsfreeze=true \
--property hw_machine_type="q35" \
--property hw_firmware_type=uefi \
--property hw_serial_port_count=1 \
--property hw_vif_model=virtio \
--property hw_vif_multiqueue_enabled=true \
--property hw_virtio_packed_ring=true \
--property hw_scsi_model=virtio-scsi \
--property hw_disk_bus=scsi \
--property hw_video_model=virtio \
--property has_auto_disk_config=true \
--property description="Ubuntu 22.04.5 (Jammy) - Cloud Image" \
--public --file ${IMGRAW} \
${NAME}
{% endhighlight %}

## Debian 12

Omnipresent and still relevant.

{% highlight shell %}
# Some helper variables
IMG=debian-12-generic-amd64.qcow2
IMGRAW="${IMG%.qcow2}.raw"
NAME=ci-debian-12-x86_64-$(date '+%Y%m%d.%H%M')

# Download the official image
wget https://cdimage.debian.org/images/cloud/bookworm/latest/${IMG}
sudo virt-customize -a ${IMG} --install qemu-guest-agent

# Convert to RAW
qemu-img convert -f qcow2 -O raw ${IMG} ${IMGRAW}

# Import
openstack image create \
--disk-format raw --container-format bare \
--progress \
--property os_type='linux' \
--property os_distro='debian' \
--property os_version='12.12' \
--property os_license=opensource \
--property os_admin_user='debian' \
--property hw_qemu_guest_agent=true \
--property os_require_quiesce=true \
--property hw_require_fsfreeze=true \
--property hw_machine_type="q35" \
--property hw_firmware_type=uefi \
--property hw_serial_port_count=1 \
--property hw_vif_model=virtio \
--property hw_vif_multiqueue_enabled=true \
--property hw_virtio_packed_ring=true \
--property hw_scsi_model=virtio-scsi \
--property hw_disk_bus=scsi \
--property hw_video_model=virtio \
--property has_auto_disk_config=true \
--property description="Debian 12.12 (Bookworm) - Cloud Image" \
--public --file ${IMGRAW} \
${NAME}
{% endhighlight %}

# Paid Images

## RedHat Enterprise Linux 10

There are some shops still require this guy. You'll have to download the file via the paid portal and place it in the working directory.

{% highlight shell %}
# Some helper variables
IMG=rhel-10.0-x86_64-kvm.qcow2
IMGRAW="${IMG%.qcow2}.raw"
NAME=ci-rhel-10.0-x86_64-$(date '+%Y%m%d.%H%M')

# Convert to RAW
qemu-img convert -f qcow2 -O raw ${IMG} ${IMGRAW}

# Import
openstack image create \
--disk-format raw --container-format bare \
--progress \
--property os_type='linux' \
--property os_distro='rhel' \
--property os_version='10.0' \
--property os_license=rhel \
--property os_admin_user='cloud-user' \
--property hw_qemu_guest_agent=true \
--property os_require_quiesce=true \
--property hw_require_fsfreeze=true \
--property hw_machine_type="q35" \
--property hw_firmware_type=uefi \
--property hw_serial_port_count=1 \
--property hw_vif_model=virtio \
--property hw_vif_multiqueue_enabled=true \
--property hw_virtio_packed_ring=true \
--property hw_scsi_model=virtio-scsi \
--property hw_disk_bus=scsi \
--property hw_video_model=virtio \
--property has_auto_disk_config=true \
--property description="RedHat Enterprise Linux 10.0 - Cloud Image" \
--public --file ${IMGRAW} \
${NAME}
{% endhighlight %}


## RedHat Enterprise Linux 9

Same but older. File needs to be downloaded and copied to the working directory.

{% highlight shell %}
# Some helper variables
IMG=rhel-9.6-x86_64-kvm.qcow2
IMGRAW="${IMG%.qcow2}.raw"
NAME=ci-rhel-9.6-x86_64-$(date '+%Y%m%d.%H%M')

# Convert to RAW
qemu-img convert -f qcow2 -O raw ${IMG} ${IMGRAW}

# Import
openstack image create \
--disk-format raw --container-format bare \
--progress \
--property os_type='linux' \
--property os_distro='rhel' \
--property os_version='9.6' \
--property os_license=rhel \
--property os_admin_user='cloud-user' \
--property hw_qemu_guest_agent=true \
--property os_require_quiesce=true \
--property hw_require_fsfreeze=true \
--property hw_machine_type="q35" \
--property hw_firmware_type=uefi \
--property hw_serial_port_count=1 \
--property hw_vif_model=virtio \
--property hw_vif_multiqueue_enabled=true \
--property hw_virtio_packed_ring=true \
--property hw_scsi_model=virtio-scsi \
--property hw_disk_bus=scsi \
--property hw_video_model=virtio \
--property has_auto_disk_config=true \
--property description="RedHat Enterprise Linux 9.6 - Cloud Image" \
--public --file ${IMGRAW} \
${NAME}
{% endhighlight %}

