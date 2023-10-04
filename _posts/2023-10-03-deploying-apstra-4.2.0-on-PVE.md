---
title: Deploying Apstra 4.2.0 on Proxmox VE
description: Export/Import vcsa virtual appliance to improve performance
layout: post
author: ciroiriarte
categories:
- HomeLab
- SDN
tags:
- Apstra
- Proxmox
- Virtualization
---

# Apstra appliances

Juniper is not distributing appliances per se for KVM deployments, but OS disk images in QCOW2 format:

**aos_server_4.2.0-236.qcow2**

Main Apstra server appliance, also used for optional workers for the scaleout setup: you use the same image for the worker nodes (didn't find this mentioned in the documentation but was mentioned by a Juniper guy)

**apstra-ztp-4.2.0-34.qcow2**

Zero Touch provisioning appliance. This is an optional ZTP appliance running PXE+TFTP. It can be used as pure TFTP with a pre-existing DHCP server.

# Installation

## Overview

For the VM sizing, the vendor has a [recommendated sizing table](https://www.juniper.net/documentation/us/en/software/apstra4.2/apstra-install-upgrade/topics/ref/apstra-server-resources.html):

|Resource | Value|
|vCPU|8|
|RAM|64GB + 500MB per installed offbox agent|
|Disk|160GB|

In my experience, that many resources are not needed, especially the RAM. For my test environment, I'll slash RAM to 32GB and most probably that's not supported, I can live with that, YMMV.

We'll create the empty virtual machines in Proxmox VE 7.4-15, importing afterwards the QCOW2 disks as needed. The procedure asumes you have downloaded all the files to a working directory (curl/wget are your friends) in a PVE node.


## Apstra OS 

### VM creation

We'll create a virtual machine with CLI, with 4 vCPUs and 32GB of RAM. 

The network is being served via the default bridge and storage via local ZFS repository. Options are self explanatory, adjust as needed.

{% highlight shell %}
VMNAME=apstra-os-03.ipa.<my TLD>
VMID=$(pvesh get /cluster/nextid)
STORAGE=local-zfs
VCPU=4
VRAM=32768
VLANLAB=<my vlan>
BRIDGE=vmbr0

# OS doesn't support UEFI
qm create ${VMID} --name ${VMNAME} \
--bios seabios --machine q35 \
--ostype l26 --agent 1 \
--sockets 1 --cores ${VCPU} --cpu cputype=kvm64 \
--scsihw virtio-scsi-single \
--memory ${VRAM} \
--net0 model=virtio,bridge=${BRIDGE},firewall=0,tag=${VLANLAB}
{% endhighlight %}

### Importing disk

Now, we'll be importing the QCOW2 file provided by Juniper.

{% highlight shell %}
VMNAME=apstra-os-03.ipa.<my TLD>
VMID=$(qm list|grep ${VMNAME}|awk '{ print $1 }')
STORAGE=local-zfs

qm disk import ${VMID} aos_server_4.2.0-236.qcow2  ${STORAGE}
qm set ${VMID} -scsi0 ${STORAGE}:vm-${VMID}-disk-1
qm set ${VMID} --boot order=scsi0
{% endhighlight %}

### Additional disk

According to the documentation, the OS disk is 80GB only and optionally you could add a second 80GB. Given it's not onerous and I won't be using additional worker nodes, I'll add the second disk.

{% highlight shell %}
VMNAME=apstra-os-03.ipa.<my TLD>
VMID=$(qm list|grep ${VMNAME}|awk '{ print $1 }')
STORAGE=local-zfs

qm set ${VMID} --scsi1 ${STORAGE}:80
# we start the VM
qm start ${VMID}
{% endhighlight %}

## ZTP appliance  

DHCP & TFTP are not that demanding, you can go with 2 vCPUs and 4GB of RAM. 

The network is being served via the default bridge and storage via local ZFS repository. Options are self explanatory, adjust as needed.

{% highlight shell %}
VMNAME=apstra-ztp-03.ipa.<my TLD>
VMID=$(pvesh get /cluster/nextid)
STORAGE=local-zfs
VCPU=2
VRAM=4096
VLANLAB=<my vlan>
BRIDGE=vmbr0

# OS doesn't support UEFI
qm create ${VMID} --name ${VMNAME} \
--bios seabios --machine q35 \
--ostype l26 --agent 1 \
--sockets 1 --cores ${VCPU} --cpu cputype=kvm64 \
--scsihw virtio-scsi-single \
--memory ${VRAM} \
--net0 model=virtio,bridge=${BRIDGE},firewall=0,tag=${VLANLAB}
{% endhighlight %}

### Importing disk

Now, we'll be importing the QCOW2 file provided by Juniper.

{% highlight shell %}
VMNAME=apstra-ztp-03.ipa.<my TLD>
VMID=$(qm list|grep ${VMNAME}|awk '{ print $1 }')
STORAGE=local-zfs

qm disk import ${VMID} apstra-ztp-4.2.0-34.qcow2  ${STORAGE}
qm set ${VMID} -scsi0 ${STORAGE}:vm-${VMID}-disk-1
qm set ${VMID} --boot order=scsi0
qm start ${VMID}
{% endhighlight %}

# Initial Configuration
## AOS setup

1. Search for the IP of the appliance in your DHCP leases and connect through SSH with admin/admin.
2. On first login set new password as requested.
3. On the forced assistant, also set the Apstra UI password as proposed. Cancel at the main menu after setting up the password.
4. Change hostname to something that makes sense for your environment. With admin user run:
    {% highlight shell %}
    sudo aos_hostname apstra-os-03.ipa.<my TLD>
    {% endhighlight %}
{:start="5"}
5. As admin, update the operating system. Juniper most probably will tell you that this is not supported. The only issue I had in the past was 4.1.0 breaking because there was a system-wide Juniper library that broke a containerized application (go figure) and required manual dependancies update to fix it. It has been flawless for 4.1.2 and now 4.2.0, pam.d files will be mentioned, keep the locally modified files.
{% highlight shell %}
sudo apt update
sudo apt upgrade -y
{% endhighlight %}
{:start="6"}
6. Reboot after full system update
sudo shutdown -r now

## ZTP appliance setup

1. Search for the IP of the appliance in your DHCP leases and connect through SSH with admin/admin.
2. Set hostname

 {% highlight shell %}
sudo hostnamectl set-hostname apstra-ztp-03.ipa.<my TLD>
sudo sh -c 'echo "127.0.0.1 apstra-ztp-03.ipa.<my TLD>" >> /etc/hosts'
{% endhighlight %}
{:start="3"}
3. Adjust timezone to match your environment.
    {% highlight shell %}
    sudo timedatectl set-timezone <my TZ>
    {% endhighlight %}
{:start="4"}
4. Update operating system. Again, probably Juniper will tell you it's not supported.
   {% highlight shell %}
sudo apt update
sudo apt upgrade -y
{% endhighlight %}
{:start="5"}
5. Reboot virtual machine
   {% highlight shell %}
sudo shutdown -r now
{% endhighlight %}

# Migration from 4.1.2

If you already have a working environment, most probably you would like to migrate all the configuration to your new installation, there is a script you should run in the new Apstra Server.

Take into account that the script will fail if there are any uncommited changes or if devices are not reachable. Make sure the running state of the source environment is clean (no errores).

{% highlight shell %}
aos_import_state --ip-address apstra-os-02.ipa.sem.lab --username admin
{% endhighlight %}

Note: 
- The configuration migration would also replace the web UI password with the configuration from the original server. 
