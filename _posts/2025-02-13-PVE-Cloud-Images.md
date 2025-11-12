---
title: PVE Cloud Images
description: Walkthrough of the process to import Cloud Images to Proxmox VE.
layout: post
author_profile: true
author: Ciro Iriarte
categories:
- Datacenter
tags:
- Virtualization
- Proxmox
---

# Intro
Cloud images are pre-configured operating system (OS) images that can be deployed in a cloud environment. The main Linux distributions offer cloud images alongside the regular ISO installers.

Minimal configuration is executed on the public images and imported as PVE templates. The procedure described underneath, expects you to create all the images (some variables defined in a given step are not necessarily re-defined in the next one).

PVE provides the feature of instantiating a VM from a template. We'll be creating templates using publicly available Cloud Images.

<!--more-->

# Pre-requisites

A fully configured PVE cluster must be set, with properly configured bridges & datastore to be used.
In one of the PVE nodes, basic tooling is required to modify the images in some cases, most notable, Ubuntu/Debian images are missing the QEMU agent.

{% highlight shell %}
apt install -y libguestfs-tools
{% endhighlight %}

# Template creation

## Basic skeleton

To simplify the rollout of the templates, we create a template VM with the common required configuration for cloud-init to work. It will be used to create the distro specific template.

This will include serial console, cloud-init disk configuration, EFI boot mode (and disk) and Q35 machine type. Also, assumes a Linux OS.


{% highlight shell %}
### We set some helper variables
# Where are we placing the template image?
DSTORE="p-replica3"
# Using Ceph as backend, we must use RAW disk images
#DSKFORMAT=qcow2
DSKFORMAT=raw
# Bridge to connect the vNIC to
BRIDGE=vmbr1
# VM ID to use as starting point
VMSKELETONID=9000
# VM name
VMSKELETON="tmpl-ci-skeleton"
# Desired bootdisk size. Cloud images are by default small (3-10GB), assign here a sensible size and don't go overboard, secondary data disks are a best practice to simplify data movement and backup/restore operations. When LVM is available, data disks should be added to a secondary volume group and not to the volume group containing the OS.
BOOTDISKSIZE=60G

### Skeleton creation
qm create ${VMSKELETONID} --name ${VMSKELETON} --cores 2 --memory 2048 \
--net0 virtio,firewall=1,bridge=${BRIDGE} --scsihw virtio-scsi-pci \
--bios ovmf --machine q35 --agent enabled=1 --ostype l26 \
--cpu cputype=max \
--serial0 socket --vga serial0 \
--efidisk0 ${DSTORE}:${VMSKELETONID},efitype=4m --scsi1 ${DSTORE}:cloudinit
{% endhighlight %}

## Find a work directory

We'll need a work directory to download and manipulate the disk images. Make sure you have enough room.

{% highlight shell %}
mkdir /tmp/cloud-images
cd /tmp/cloud-images
{% endhighlight %}

## Opensuse

{% highlight shell %}
# We increment VMID starting from the skeleton machine ID
let VMID=VMSKELETONID+1
# Filename in source
IMG=openSUSE-Leap-15.6.x86_64-NoCloud.qcow2
# Name we'll give to the template
VMNAME="tmpl-ci-opensuse-15.6"

# Download the official image
wget https://download.opensuse.org/repositories/Cloud%3A/Images%3A/Leap_15.6/images/${IMG}
qemu-img resize ${IMG} ${BOOTDISKSIZE}

# Fix PTP synchronization
echo ptp_kvm > /tmp/ptp_kvm.conf
virt-customize -a ${IMG} --copy-in /tmp/ptp_kvm.conf:/etc/modules-load.d/

# Clone our skeleton machine (full clone)
qm clone ${VMSKELETONID} ${VMID} --name ${VMNAME} --full 1
# Import disk in a cluster-wide datastore
qm importdisk ${VMID} ${IMG} ${DSTORE} --format ${DSKFORMAT}
# We attach the disk, mimic SSD and enable discard/unmap
qm set ${VMID} --scsihw virtio-scsi-pci --scsi0 ${DSTORE}:vm-${VMID}-disk-1,discard=on,ssd=1
# Define boot options to use the disk
qm set ${VMID} --boot c --bootdisk scsi0
# Set VM as template
qm template ${VMID}
# Cleanup
rm ${IMG}
{% endhighlight %}

### Rocky Linux 9

{% highlight shell %}
let VMID=VMID+1
IMG=Rocky-9-GenericCloud-LVM-9.5-20241118.0.x86_64.qcow2
VMNAME="tmpl-ci-rocky-9"

wget https://dl.rockylinux.org/pub/rocky/9/images/x86_64/${IMG}
qemu-img resize ${IMG} ${BOOTDISKSIZE}

qm clone ${VMSKELETONID} ${VMID} --name ${VMNAME} --full 1
qm importdisk ${VMID} ${IMG} ${DSTORE} --format ${DSKFORMAT}
qm set ${VMID} --scsihw virtio-scsi-pci --scsi0 ${DSTORE}:vm-${VMID}-disk-1,discard=on,ssd=1
qm set ${VMID} --boot c --bootdisk scsi0
qm template ${VMID}
rm ${IMG}
{% endhighlight %}

### Oracle Linux 9

{% highlight shell %}
let VMID=VMID+1
IMG=OL9U5_x86_64-kvm-b259.qcow2
VMNAME="tmpl-ci-oel-9"

wget https://yum.oracle.com/templates/OracleLinux/OL9/u5/x86_64/${IMG}

qm clone ${VMSKELETONID} ${VMID} --name ${VMNAME} --full 1
qm importdisk ${VMID} ${IMG} ${DSTORE} --format ${DSKFORMAT}
qm set ${VMID} --scsihw virtio-scsi-pci --scsi0 ${DSTORE}:vm-${VMID}-disk-1,discard=on,ssd=1
qm set ${VMID} --boot c --bootdisk scsi0
qm template ${VMID}
rm ${IMG}
{% endhighlight %}

### Ubuntu 24.04

{% highlight shell %}
let VMID=VMID+1
IMG=noble-server-cloudimg-amd64.img
VMNAME="tmpl-ci-ubuntu-24.04"

wget https://cloud-images.ubuntu.com/noble/current/${IMG}
virt-customize -a ${IMG} --install qemu-guest-agent
qemu-img resize ${IMG} ${BOOTDISKSIZE}

qm clone ${VMSKELETONID} ${VMID} --name ${VMNAME} --full 1
qm importdisk ${VMID} ${IMG} ${DSTORE} --format ${DSKFORMAT}
qm set ${VMID} --scsihw virtio-scsi-pci --scsi0 ${DSTORE}:vm-${VMID}-disk-1,discard=on,ssd=1
qm set ${VMID} --boot c --bootdisk scsi0
qm template ${VMID}
rm ${IMG}
{% endhighlight %}

### Ubuntu 22.04

{% highlight shell %}
let VMID=VMID+1
IMG=jammy-server-cloudimg-amd64.img
VMNAME="tmpl-ci-ubuntu-22.04"

wget https://cloud-images.ubuntu.com/jammy/current/${IMG}
virt-customize -a ${IMG} --install qemu-guest-agent
qemu-img resize ${IMG} ${BOOTDISKSIZE}

qm clone ${VMSKELETONID} ${VMID} --name ${VMNAME} --full 1
qm importdisk ${VMID} ${IMG} ${DSTORE} --format ${DSKFORMAT}
qm set ${VMID} --scsihw virtio-scsi-pci --scsi0 ${DSTORE}:vm-${VMID}-disk-1,discard=on,ssd=1
qm set ${VMID} --boot c --bootdisk scsi0
qm template ${VMID}
rm ${IMG}
{% endhighlight %}

### Debian 12

{% highlight shell %}
let VMID=VMID+1
IMG=debian-12-generic-amd64.qcow2
VMNAME="tmpl-ci-debian-12"

wget https://cdimage.debian.org/images/cloud/bookworm/latest/${IMG}
virt-customize -a ${IMG} --install qemu-guest-agent
qemu-img resize ${IMG} ${BOOTDISKSIZE}

qm clone ${VMSKELETONID} ${VMID} --name ${VMNAME} --full 1
qm importdisk ${VMID} ${IMG} ${DSTORE} --format ${DSKFORMAT}
qm set ${VMID} --scsihw virtio-scsi-pci --scsi0 ${DSTORE}:vm-${VMID}-disk-1,discard=on,ssd=1
qm set ${VMID} --boot c --bootdisk scsi0
qm template ${VMID}
rm ${IMG}
{% endhighlight %}



# VM provisioning from a template

Once the templates are available, you can use them via Web UI, Terraform or CLI. We'll demostrate how to deploy a VM using CLI on one of the PVE hosts.

## VM creation

{% highlight shell %}
##
# Variables
##

# Template to use
TMPL=tmpl-ci-opensuse-15.6
# Bridge to use
NETBR=frontend
# VM IP
NETIP="192.168.0.100/24"
# Network gateway
NETGW="192.168.0.1"
# DNS setup
DNS=8.8.8.8
DNSSEARCH="my.domain"
# VM name
NEWVMNAME=test001.mydomain.com
# Credentials
GUESTUSER=cloudadmin
GUESTPASS=Cambiar456
MYKEY="ssh-rsa … Comment"
KEYFILE=/tmp/ssh-%{RANDOM}
echo ${MYKEY} > ${KEYFILE}

# We get the next available VMID
NEWVM_ID=$(pvesh get /cluster/nextid)
# Fetching template id using the template name
TMPL_ID=$(pvesh get /cluster/resources --type vm --noborder|grep ${TMPL}| awk '{ print $1 }'|cut -f 2 -d "/")

##
# Actual provisioning
##

# We clone template to create the new VM, full clone (by default a template spawns linked clones)
qm clone ${TMPL_ID} ${NEWVM_ID} --name ${NEWVMNAME} --full 1
# Remove and reassign the network device with the correct bridge
qm set ${NEWVM_ID} --delete net0
qm set ${NEWVM_ID} -net0 virtio,firewall=1,bridge=${NETBR}
# Define cloud-init variables
qm set ${NEWVM_ID} --ciuser ${GUESTUSER} --cipassword ${GUESTPASS}
qm set ${NEWVM_ID} --sshkeys "${KEYFILE}" && rm ${KEYFILE}
qm set ${NEWVM_ID} --ipconfig0 ip=${NETIP},gw=${NETGW}
qm set ${NEWVM_ID} --nameserver ${DNS} --searchdomain "${DNSSEARCH}"
# Optionally, disable package upgrades in first boot. With repository access (Internet or local mirror), leave it as is.
#qm set ${NEWVM_ID} --ciupgrade 0
# Start the VM
qm start ${NEWVM_ID}
# Optionally, attach this session to the VM console (ctrl+o to disconnect afterwards)
qm terminal ${NEWVM_ID}
{% endhighlight %}

## Optionals

You can add secondary network interfaces and disks to a machine. Example follows.

### Network

{% highlight shell %}
# Defined bridges we're using for the attach operation
NET1=patito
NET2=cangrejo
NET3=zapallo
# Create interfaces and define attachment
qm set ${NEWVM_ID} -net1 virtio,firewall=1,bridge=${NET1}
qm set ${NEWVM_ID} -net2 virtio,firewall=1,bridge=${NET2}
qm set ${NEWVM_ID} -net3 virtio,firewall=1,bridge=${NET3}
{% endhighlight %}

### Storage

{% highlight shell %}
# Primary replicated data.
DSTORE1="p-replica3"
# Secondary data, erasure coding.
DSTORE2="ec2-1"

# Create vdisk. Long syntax 
qm set ${NEWVM_ID} --scsi1 ${DSTORE1}:vm-${NEWVM_ID}-disk-2,size=200G,discard=on,ssd=1
# Create vdisk. Simplified syntax, size assumed in GB
qm set ${NEWVM_ID} --scsi1 ${DSTORE2}:500,discard=on,ssd=1
{% endhighlight %}


