---
title: vSAN ESA on ESXi-over-PVE
description: Nested vSAN ESA cluster for testing purposes
layout: post
author: ciroiriarte
categories:
- HomeLab
tags:
- ESXi
- Proxmox
- Nested
- Virtualization
- vSAN
---

# vSAN OSA
One of my biggest griefs as a customer regarding the VMware SDDC offering is vSAN OSA. When I first saw it in action, it looked like a "me too" response to [Nutanix](https://www.nutanix.com/mx/info/software-defined-storage), which we introduced successfully I believe as a first customer in Paraguay during 2016-ish (if memory serves right). 

Also, coming from the background of FiberChannel based solutions like [EMC's vMAX](https://www.youtube.com/watch?v=Zp3yMGlzZhM) & [Hitachi's VSP](https://knowledge.hitachivantara.com/Documents/Storage/VSP_G1X00_and_VSP_F1500/80-06-6x/Hardware_Guide/03_Hardware_architecture) it was a really hard sell feature wise (no snapshots, no tiering, no replication, etc) and going with 20 nodes clusters just because we needed capacity for big fat Oracle Databases didn't make sense (it's not cost effective)

Another way of seeing it, if you compare it to other solutions serving Xen or KVM, it lacks flexibility (single pool per cluster, single disk type, cache drive as important failure points, etc) and when non-ESXi at sight, we would just go with any other alternatives like [CEPH](https://docs.ceph.com/en/latest/architecture/) or [MooseFS](https://moosefs.com/blog/architecture/) in the past (no [GlusterFS](https://docs.gluster.org/en/main/Quick-Start-Guide/Architecture/), nobody likes you....)

On the bright side, it makes sense if you're a VMware shop with very limited teams regarding infra and you want a quick way to introduce a virtualization platform, or no Centralized Storage + SAN in place to start with and your storage needs are not disproportionate in comparison with compute.

# vSAN ESA
First time I heard about [vSAN ESA](https://core.vmware.com/blog/introduction-vsan-express-storage-architecture) was in the 2022 VMware Explore event. It's not perfect, but it's a step in the right direction.

Make sure you watch the "Get to Know the Next-Generation of vSAN Architecture" on demand VMware Explore 2022 session.

# Going back to our Proxmox nested environment.
If you would like to get your feet wet, vSAN ESA can be deployed in our nested ESX-on-KVM/Proxmox environment. Of course, it won't be supported, but will allow you to play with it.

Warnings will be present, because we don't meet any [supported configuration](https://kb.vmware.com/s/article/90343):
- 25GbE interfaces
- NVMe controllers
- 512GB RAM per node
etc....

In the ideal world, we should use a NVMe controller, which QEMU supports, but [Proxmox doesn't support yet](https://bugzilla.proxmox.com/show_bug.cgi?id=2255). Given that scenario, we're going with the default SATA controller.

# Provisioning of the disks

For this test, we'll take 3 nested ESXi instances and add to each 3 x 100GB disks emulating SSD.

{% highlight shell %}
STORAGE=dstore01
for VM in esxi01 esxi02 esxi03
do
    # We get the ID to operate on the VM
    VMID=$(qm list|grep ${VM}|awk '{ print $1 }')
    # Adding disks, emulating SSD
    qm set $VMID --sata3 ${STORAGE}:100,format=qcow2,ssd=1,discard=on \
        --sata4 ${STORAGE}:100,format=qcow2,ssd=1,discard=on \
        --sata5 ${STORAGE}:100,format=qcow2,ssd=1,discard=on
done
{% endhighlight %}

# vSAN Setup

You can setup the vSAN Cluster as you would normally do, during vCenter Deployment or after having it up & running.

First warning you would see, is that the NICs are not supported (25GbE is mandated). You can keep moving forward eitherway.

<figure>
  <a href="/assets/img/2023-09-07-nic-speed-warning.png">
  <img src="/assets/img/2023-09-07-nic-speed-warning.png" alt="NIC warning"/>
  </a>
  <figcaption><i>Image 1 - NIC warning</i></figcaption>
</figure>

If you keep moving forward, disks will be marked as incompatible. Just claim them manually.

<figure>
  <a href="/assets/img/2023-09-07-incompatible-disk-warning.png">
  <img src="/assets/img/2023-09-07-incompatible-disk-warning.png" alt="Disk marked as not compatible"/>
  </a>
  <figcaption><i>Image 2 - Disk marked as not compatible</i></figcaption>
</figure>

<figure>
  <a href="/assets/img/2023-09-07-disk-claiming.png">
  <img src="/assets/img/2023-09-07-disk-claiming.png" alt="Manual claim"/>
  </a>
  <figcaption><i>Image 3 - Manual claim</i></figcaption>
</figure>

# Outome

After some minutes, you should have your working-but-not-supported ESXi-nested-on-PVE-vSAN cluster.

Have fun!