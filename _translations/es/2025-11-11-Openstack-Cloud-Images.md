---
title: "Imágenes Cloud para Openstack"
description: "Recorrido por el proceso de importación de Cloud Images a Openstack."
date: 2025-11-11 00:00:00 -0300
permalink: /es/datacenter/2025/11/11/Openstack-Cloud-Images.html
lang: es
categories:
  - virtualization
tags:
  - openstack
  - cloud-images
---

Una vez que tienes tu flamante entorno Openstack funcionando, querrás empezar de inmediato a aprovisionar máquinas virtuales. El punto de partida son las imágenes de sistema operativo, que proveen la copia base del sistema operativo para tus nuevas máquinas virtuales.

Las imágenes incluyen tanto los datos del disco del SO como lo que normalmente serían propiedades de la máquina virtual en otras plataformas de virtualización.

Aquí te presento un procedimiento para preparar imágenes de nivel productivo provenientes de los proveedores habituales de distribuciones Linux.

<!--more-->

## Cloud Images {#cloud-images}

Entran en escena las ["Cloud Images"](https://docs.openstack.org/image-guide/obtain-images.html). Estas imágenes de SO son básicamente instancias preparadas/curadas por los distintos proyectos (o empresas) de distribuciones Linux, listas para arrancar en un entorno cloud (AWS, Azure, GCP, Openstack, etc). Puedes considerarlas tan seguras como el instalador ISO que descargas para tu distribución favorita, tienen una huella mínima y normalmente incluyen cloud-init para automatizar el proceso de despliegue.

En Openstack, cloud-init es crítico para el despliegue, ya que no quieres redimensionar el disco de arranque, agregar usuarios ni configurar TCP/IP a mano. Además, se recomienda mucho QEMU Guest Agent al virtualizar sobre KVM, para habilitar respaldos consistentes y permitir algo de automatización del inventario operativo.

Las distribuciones Linux pagas (como SLES o RHEL) también proveen cloud images. No logro encontrar una imagen Cloud de Windows Server 2025 para descargar (¡vergüenza Microsoft!).

## Configuración {#configuration}

La definición real de la máquina virtual debe establecerse como propiedades durante el proceso de importación de la imagen de disco. Las definiremos nosotros, ya que no forman parte de los archivos de Cloud Images que descargas.

Algunos atributos que propongo aquí aportan documentación adecuada (nombre, versión, licenciamiento, etc.), otros aportan buenas prácticas de rendimiento (tipo de máquina, tipos de NIC/HBA) u operativas (parámetros relacionados con respaldos).

## Formato de disco {#disk-format}

En mi caso, uso Ceph RBD como backend de Cinder. Si le dices a Cinder/Nova que cree un volumen a partir de una imagen qcow2, primero descargará la imagen, la convertirá a raw y luego la volverá a subir a Ceph. Esto consume mucho más espacio en Ceph, más ancho de banda de red y es propenso a timeouts si la conversión y la subida tardan demasiado.

Si usas un backend de sistema de archivos, ve con QCOW2, pero si usas Ceph RBD como yo, ve con RAW para aprovechar la clonación Copy-on-Write de las imágenes tanto en Cinder como en Nova y obtener tiempos de instanciación más rápidos.
 

## Herramientas {#tooling}

Dependiendo de la máquina en la que estés trabajando, instala guestfs-tools. Esto nos permitirá personalizar la imagen.

openSUSE:

{% highlight shell %}
sudo zypper install -y guestfs-tools
{% endhighlight %}

Ubuntu:

{% highlight shell %}
sudo apt install -y libguestfs-tools whois
{% endhighlight %}

## Imágenes gratuitas {#free-images}

Busca un lugar donde descargar archivos

{% highlight shell %}
mkdir cloud-images
cd cloud-images
{% endhighlight %}
	
### openSUSE {#opensuse}

Mi favorita personal; descargaremos Leap, que es muy similar a SLES (la versión comercial de la distribución). Otras alternativas son Tumbleweed (lo último de lo último) o Slowroll ("quiero algo más nuevo, pero sin volverme loco").

Ya soporta cloud-init, solo habilitamos el soporte para el dispositivo PTP para que chrony lo use como referencia de tiempo. El host KVM básicamente lo provee para que los guests [sincronicen la hora](https://www.libertysys.com.au/2024/04/vm-timekeeping-using-the-ptp-hardware-clock-on-kvm/) y, al contrario de lo que ocurre con VMware Guest Tools, QEMU Guest Agent no provee capacidades de sincronización de hora.

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

La herramienta habitual para los refugiados de CentOS. Cloud-init viene disponible de fábrica. 

#### Imagen basada en LVM {#lvm-based-image}

Si quieres tener todos tus sistemas de archivos bajo gestión de LVM, el proyecto provee una imagen específica. El único inconveniente es que el redimensionamiento de sistemas de archivos de cloud-init no funcionará y se requerirán maniobras manuales (no esperes que los usuarios Linux hardcore tengan problema con eso).

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


#### Imagen con particiones simples {#bare-partitions-image}

Esta imagen tiene particiones simples para los sistemas de archivos del sistema operativo. Como con cualquier otra imagen Linux, aún puedes usar LVM para los discos de datos (y probablemente deberías, ya que Openstack no soporta la migración en caliente entre pools de Ceph y LVM dentro del guest puede salvarte el día cuando se requiera reubicar datos)

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

Esta es una rara y nunca he sido fan. Otro clon de RHEL con ventajas injustas respecto a las reglas de licenciamiento inventadas de Oracle. Al igual que Ubuntu, puedes pagar soporte o no. Los repositorios son públicos.

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

Distribución omnipresente; si te gusta Debian te sentirás en casa.

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

Versión más antigua de Ubuntu que aún se usa.

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

Omnipresente y todavía relevante.

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

## Imágenes pagas {#paid-images}

### RedHat Enterprise Linux 10 {#redhat-enterprise-linux-10}

Hay empresas que todavía requieren a este señor. Tendrás que descargar el archivo desde el portal pago y colocarlo en el directorio de trabajo.

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

Lo mismo pero más antiguo. El archivo debe descargarse y copiarse al directorio de trabajo.

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

## ¿Cómo usar las imágenes? {#how-to-use-the-images}

Entonces, después de toda esa preparación, deberíamos poder instanciar una máquina virtual y configurarla automáticamente con cloud-init con el procedimiento que sigue.

Tomará la imagen, creará un disco virtual con el tamaño adecuado para que el sistema operativo arranque y creará nuestra flamante VM con los parámetros definidos en la imagen. Como ejemplo rápido de lo que se puede hacer con cloud-init, también instalamos e iniciamos un servidor web con una página de inicio básica para publicar.

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

## Oportunidades de mejora {#improvement-opportunities}

Bueno, el procedimiento compartido construye un buen punto de partida. Cosas que veo que hay que abordar:

### 1- ptp_kvm para todos los guests {#1--ptp_kvm-for-all-the-guests}

El módulo del kernel parece estar soportado por RHEL y clones como Rocky u OEL:
- [KVM Guest Timing Management](https://docs.redhat.com/en/documentation/red_hat_enterprise_linux/7/html/virtualization_deployment_and_administration_guide/chap-kvm_guest_timing_management)

Parece no estar soportado por Ubuntu. Te quedan solo NTP contra servidores conectados por red o ninguna sincronización (mala opción):
- [LP #1896311](https://bugs.launchpad.net/ubuntu/+source/linux-kvm/+bug/1896311)
- [LP #1950878](https://bugs.launchpad.net/ubuntu/+source/linux-meta-kvm/+bug/1950878)

Necesito encontrar tiempo para probar y documentar el procedimiento de configuración

### 2- Licenciamiento del SO {#2--os-licensing}

Se requiere configuración adicional para asociar correctamente las instancias guest pagas con un subconjunto de nodos de un despliegue de Openstack dado. He identificado dos opciones (propiedades de imagen + Host Aggregates o traits), pero se requieren pruebas reales.

### 3- Guests con Windows Server {#3--windows-server-guests}

Parece seguir siendo un mal necesario en 2025 para las grandes organizaciones. Necesito encontrar tiempo para crear un procedimiento de creación de imágenes; debería incluir Cloudbase-init como alternativa a cloud-init.
