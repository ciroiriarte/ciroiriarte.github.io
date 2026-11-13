---
title: "Cloud Image per Openstack"
description: "Guida passo passo al processo di importazione delle Cloud Image in Openstack."
date: 2025-11-11 00:00:00 -0300
permalink: /it/datacenter/2025/11/11/Openstack-Cloud-Images.html
lang: it
categories:
  - virtualization
tags:
  - openstack
  - cloud-images
---

Una volta che il tuo fiammante ambiente Openstack è attivo e funzionante, vorrai iniziare subito a creare macchine virtuali. Il punto di partenza sono le immagini del sistema operativo, che forniscono la copia di base del sistema operativo da usare per le tue nuove macchine virtuali.

Le immagini includono sia i dati del disco del SO sia quelle che in altre piattaforme di virtualizzazione sarebbero normalmente le proprietà della macchina virtuale.

Qui ti presento una procedura per preparare immagini di livello produttivo provenienti dai soliti fornitori di distribuzioni Linux.

<!--more-->

## Cloud Images {#cloud-images}

Entrano in scena le ["Cloud Images"](https://docs.openstack.org/image-guide/obtain-images.html). Queste immagini del SO sono sostanzialmente istanze preparate/curate dai vari progetti (o aziende) di distribuzioni Linux, pronte per avviarsi in un ambiente cloud (AWS, Azure, GCP, Openstack, ecc). Puoi considerarle sicure quanto l'installer ISO che scarichi per la tua distribuzione preferita, hanno un'impronta minima e di solito includono cloud-init per automatizzare il processo di deployment.

In Openstack cloud-init è fondamentale per il deployment, perché non vuoi ridimensionare a mano il disco di boot, aggiungere utenti o configurare TCP/IP. Inoltre, quando si virtualizza su KVM, QEMU Guest Agent è altamente raccomandato per abilitare backup consistenti e permettere un po' di automazione dell'inventario operativo.

Anche le distribuzioni Linux a pagamento (come SLES o RHEL) forniscono cloud image. Non riesco a trovare un'immagine Cloud di Windows Server 2025 da scaricare (vergognati Microsoft!).

## Configurazione {#configuration}

La definizione effettiva della macchina virtuale va impostata come proprietà durante il processo di importazione dell'immagine disco. Le definiremo noi, dato che non fanno parte dei file Cloud Images che scarichi.

Alcuni attributi che propongo qui forniscono una documentazione adeguata (nome, versione, licenze, ecc.), altri forniscono best practice di prestazioni (tipo di macchina, tipi di NIC/HBA) oppure operative (parametri relativi ai backup).

## Formato del disco {#disk-format}

Nel mio caso uso Ceph RBD come backend di Cinder. Se dici a Cinder/Nova di creare un volume da un'immagine qcow2, prima scaricherà l'immagine, la convertirà in raw e poi la ricaricherà su Ceph. Questo consuma molto più spazio in Ceph, più banda di rete ed è soggetto a timeout se la conversione e il caricamento durano troppo.

Se usi un backend su filesystem vai con QCOW2, ma se usi Ceph RBD come me, vai con RAW per sfruttare il cloning Copy-on-Write delle immagini sia in Cinder che in Nova e avere tempi di istanziazione più rapidi.
 

## Strumenti {#tooling}

A seconda della macchina su cui stai lavorando, installa guestfs-tools. Questo ci permetterà di personalizzare l'immagine.

openSUSE:

{% highlight shell %}
sudo zypper install -y guestfs-tools
{% endhighlight %}

Ubuntu:

{% highlight shell %}
sudo apt install -y libguestfs-tools whois
{% endhighlight %}

## Immagini gratuite {#free-images}

Trova un posto dove scaricare i file

{% highlight shell %}
mkdir cloud-images
cd cloud-images
{% endhighlight %}
	
### openSUSE {#opensuse}

La mia preferita personale; scaricheremo Leap, che è molto simile a SLES (la versione commerciale della distribuzione). Altre alternative sono Tumbleweed (bleeding edge) o Slowroll ("voglio qualcosa di più recente, ma senza esagerare").

Supporta già cloud-init, abilitiamo solo il supporto per il dispositivo PTP da usare come riferimento temporale per chrony. L'host KVM sostanzialmente lo fornisce ai guest per [sincronizzare l'ora](https://www.libertysys.com.au/2024/04/vm-timekeeping-using-the-ptp-hardware-clock-on-kvm/) e, al contrario di quanto accade con VMware Guest Tools, QEMU Guest Agent non fornisce funzionalità di sincronizzazione dell'ora.

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


### Rocky Linux {#rocky-linux}

Lo strumento abituale per i profughi di CentOS. Cloud-init è disponibile di serie. 

#### Immagine basata su LVM {#lvm-based-image}

Nel caso tu voglia avere tutti i filesystem gestiti da LVM, il progetto fornisce un'immagine apposita. Unico svantaggio: il ridimensionamento del filesystem di cloud-init non funzionerà e serviranno manovre manuali (non aspettarti che gli utenti Linux hardcore abbiano problemi con questo).

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


#### Immagine con partizioni semplici {#bare-partitions-image}

Questa immagine ha partizioni semplici per i filesystem del sistema operativo. Come con qualsiasi altra immagine Linux, puoi comunque usare LVM per i dischi dati (e probabilmente dovresti, dato che la migrazione a caldo tra pool Ceph non è supportata da Openstack e LVM nel guest può salvare la giornata quando serve spostare i dati)

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

### Oracle Enterprise Linux 9 {#oracle-enterprise-linux-9}

Questa è strana e non ne sono mai stato un fan. Un altro clone di RHEL con vantaggi sleali rispetto alle regole di licenza inventate da Oracle. Come per Ubuntu, puoi pagare il supporto oppure no. I repository sono pubblici.

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

### Ubuntu 24.04 {#ubuntu-2404}

Distribuzione onnipresente; se ti piace Debian ti sentirai a casa.

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

### Ubuntu 22.04 {#ubuntu-2204}

Versione più vecchia di Ubuntu, ancora in uso.

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

### Debian 12 {#debian-12}

Onnipresente e ancora attuale.

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

## Immagini a pagamento {#paid-images}

### RedHat Enterprise Linux 10 {#redhat-enterprise-linux-10}

Ci sono aziende che ancora richiedono questo signore. Dovrai scaricare il file dal portale a pagamento e metterlo nella directory di lavoro.

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


### RedHat Enterprise Linux 9 {#redhat-enterprise-linux-9}

Uguale ma più vecchia. Il file va scaricato e copiato nella directory di lavoro.

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

## Come usare le immagini? {#how-to-use-the-images}

Quindi, dopo tutta questa preparazione, dovremmo poter istanziare una macchina virtuale e configurarla automaticamente con cloud-init con la procedura qui sotto.

Prenderà l'immagine, creerà un disco virtuale della dimensione giusta da cui il sistema operativo possa avviarsi e istanzierà la nostra fiammante VM con i parametri definiti nell'immagine. Come rapido esempio di ciò che si può fare con cloud-init, installiamo e avviamo anche un web server con una semplice pagina di benvenuto da pubblicare.

{% highlight shell %}
##
# Credentials
##

source novarc

## 
# Helper variables
##
# Network that will host the VM
TESTNETWORK="tnt01-dflt-internal-net"
# Alternative reference by ID
TESTNETWORKID=$(openstack network show ${TESTNETWORK} -f json| jq .id|tr -d '"')
# VM name
TESTVMNAME="prd-mysuper-vm-001"
# VM flavor to use
FLAVOR=c4a.4c-8G
# Base image to use
IMAGE=ci-opensuse-leap-16.0-x86_64-20251111.2246
# OS Disk size in GB
OSDISKSIZE=60
# Were we put the temporary files
TMPDIR=tmpdir-${RANDOM}
# User account to use
MYUSER=cloudadmin
# Our SSH public key for authentication
SSHKEY="ssh-ed25519 AAAA...Ica5ij ciro@laptop001"

##
# Creation procedure
##

# We create our cloud-init config file
mkdir -p ${TMPDIR}

cat > ${TMPDIR}/userdata.yaml <<EOF
#cloud-config
hostname: ${TESTVMNAME}
users:
  - name: ${MYUSER}
    ssh-authorized-keys:
      - ${SSHKEY}
    sudo: ALL=(ALL) NOPASSWD:ALL
    shell: /bin/bash
#packages:
#  - vim
#  - curl
#  - apache2
runcmd:
  # Add repository
  - zypper ar -f -c https://download.opensuse.org/distribution/leap/16.0/repo/oss/x86_64/ leap-16-oss
  - zypper in -y vim curl apache2
  # Enable and start Apache
  - systemctl enable apache2
  - systemctl start apache2
  # Create Simple index.html
  - ['sh', '-c', 'echo "<h1>Hello world!</h1>" > /srv/www/htdocs/index.html']
- # Firewall is not present
  #- firewall-cmd --permanent --add-service=http
  #- firewall-cmd --reload
EOF

# Create the VM instance
openstack server create \
--image ${IMAGE} \
--flavor ${FLAVOR} \
--network ${TESTNETWORK} \
--use-config-drive \
--user-data ${TMPDIR}/userdata.yaml \
--boot-from-volume ${OSDISKSIZE} \
${TESTVMNAME}

# List all the VMs
openstack server list
{% endhighlight %}

## Opportunità di miglioramento {#improvement-opportunities}

Beh, la procedura condivisa costruisce un buon punto di partenza. Cose che vedo da affrontare:

### 1- ptp_kvm per tutti i guest {#1--ptp_kvm-for-all-the-guests}

Il modulo del kernel sembra essere supportato da RHEL e cloni come Rocky o OEL:
- [KVM Guest Timing Management](https://docs.redhat.com/en/documentation/red_hat_enterprise_linux/7/html/virtualization_deployment_and_administration_guide/chap-kvm_guest_timing_management)

Non sembra essere supportato da Ubuntu. Ti restano o NTP verso server raggiungibili in rete o nessuna sincronizzazione (scelta pessima):
- [LP #1896311](https://bugs.launchpad.net/ubuntu/+source/linux-kvm/+bug/1896311)
- [LP #1950878](https://bugs.launchpad.net/ubuntu/+source/linux-meta-kvm/+bug/1950878)

Devo trovare il tempo di testare e documentare la procedura di configurazione

### 2- Licenze del SO {#2--os-licensing}

Serve una configurazione aggiuntiva per associare correttamente le istanze guest a pagamento a un sottoinsieme di nodi di un dato deployment Openstack. Ho individuato due opzioni (proprietà dell'immagine + Host Aggregates o trait), ma servono test reali.

### 3- Guest Windows Server {#3--windows-server-guests}

Sembra essere ancora un male necessario nel 2025 per le grandi organizzazioni. Devo trovare il tempo di creare una procedura per la creazione delle immagini; dovrebbe includere Cloudbase-init come alternativa a cloud-init.
