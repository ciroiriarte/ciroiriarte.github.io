---
title: Cloud Images no PVE
description: "Passo a passo do processo de importação de Cloud Images para o Proxmox VE."
date: 2025-02-13 00:00:00 -0300
permalink: /pt/datacenter/2025/02/13/PVE-Cloud-Images.html
lang: pt
categories:
  - virtualization
tags:
  - proxmox
  - cloud-images
---

## Introdução {#intro}
Cloud images são imagens de sistema operacional (SO) pré-configuradas que podem ser implantadas em um ambiente cloud. As principais distribuições Linux oferecem cloud images junto com os instaladores ISO tradicionais.

Uma configuração mínima é executada nas imagens públicas e elas são importadas como templates do PVE. O procedimento descrito abaixo espera que você crie todas as imagens (algumas variáveis definidas em um passo não são necessariamente redefinidas no seguinte).

O PVE oferece a possibilidade de instanciar uma VM a partir de um template. Vamos criar templates usando Cloud Images disponíveis publicamente.

<!--more-->

> **Nota:** Para facilitar o uso, esse conhecimento foi incorporado a um script disponível em [pve-import-cloud-images](https://github.com/ciroiriarte/pve-scripts/blob/master/pve-import-cloud-images).

## Pré-requisitos {#pre-requisites}

É preciso ter um cluster PVE totalmente configurado, com bridges e datastore corretamente configurados para uso.
Em um dos nós do PVE, são necessárias ferramentas básicas para modificar as imagens em alguns casos; principalmente, as imagens do Ubuntu/Debian não têm o agente QEMU.

{% highlight shell %}
apt install -y libguestfs-tools
{% endhighlight %}

## Criação de templates {#template-creation}

### Esqueleto básico {#basic-skeleton}

Para simplificar a implantação dos templates, criamos uma VM template com a configuração comum necessária para o cloud-init funcionar. Ela será usada para criar o template específico de cada distro.

Isso inclui console serial, configuração do disco do cloud-init, modo de boot EFI (e disco) e tipo de máquina Q35. Além disso, assume um SO Linux.


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

### Encontre um diretório de trabalho {#find-a-work-directory}

Precisaremos de um diretório de trabalho para baixar e manipular as imagens de disco. Garanta que haja espaço suficiente.

{% highlight shell %}
mkdir /tmp/cloud-images
cd /tmp/cloud-images
{% endhighlight %}

### Opensuse {#opensuse}

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

#### Rocky Linux 9 {#rocky-linux-9}

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

#### Oracle Linux 9 {#oracle-linux-9}

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

#### Ubuntu 24.04 {#ubuntu-2404}

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

#### Ubuntu 22.04 {#ubuntu-2204}

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

#### Debian 12 {#debian-12}

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



## Provisionamento de uma VM a partir de um template {#vm-provisioning-from-a-template}

Com os templates disponíveis, você pode usá-los via Web UI, Terraform ou CLI. Vamos demonstrar como implantar uma VM usando a CLI em um dos hosts PVE.

### Criação da VM {#vm-creation}

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

### Opcionais {#optionals}

Você pode adicionar interfaces de rede e discos secundários a uma máquina. Segue um exemplo.

#### Rede {#network}

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

#### Armazenamento {#storage}

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
