---
title: Desplegando Apstra 4.2.0 en Proxmox VE
description: "Despliegue paso a paso de los appliances Apstra 4.2.0 AOS y ZTP"
date: 2023-10-03 00:00:00 -0300
permalink: /es/homelab/sdn/2023/10/03/deploying-apstra-4.2.0-on-PVE.html
lang: es
categories:
  - virtualization
  - networking
tags:
  - proxmox
  - apstra
---

## Appliances de Apstra {#apstra-appliances}

Juniper no distribuye appliances propiamente dichos para despliegues en KVM, sino imágenes de disco del sistema operativo en formato QCOW2:

**aos_server_4.2.0-236.qcow2**

Appliance principal del servidor Apstra, que también se usa para los workers opcionales de la configuración scale-out: se usa la misma imagen para los nodos worker (no encontré esto mencionado en la documentación, pero lo mencionó un tipo de Juniper).

**apstra-ztp-4.2.0-34.qcow2**

Appliance opcional de Zero Touch Provisioning (ZTP) que ejecuta PXE+TFTP. Se puede usar como TFTP puro con un servidor DHCP preexistente.

## Instalación {#installation}

### Resumen {#overview}

Para el dimensionamiento de las VMs, el fabricante tiene una [tabla de dimensionamiento recomendado](https://www.juniper.net/documentation/us/en/software/apstra4.2/apstra-install-upgrade/topics/ref/apstra-server-resources.html):

|Resource | Value|
|vCPU|8|
|RAM|64GB + 500MB per installed offbox agent|
|Disk|160GB|

En mi experiencia no hacen falta tantos recursos, especialmente de RAM. Para mi entorno de pruebas voy a recortar la RAM a 32GB y lo más probable es que eso no esté soportado, puedo vivir con eso, tu caso puede variar.

Vamos a crear las máquinas virtuales vacías en Proxmox VE 7.4-15 e importar después los discos QCOW2 según corresponda. El procedimiento asume que descargaste todos los archivos a un directorio de trabajo (curl/wget son tus amigos) en un nodo PVE.


### Apstra OS {#apstra-os}

#### Creación de la VM {#vm-creation}

Vamos a crear una máquina virtual por CLI, con 4 vCPUs y 32GB de RAM. 

La red se sirve mediante el bridge por defecto y el almacenamiento mediante el repositorio ZFS local. Las opciones se explican solas, ajústalas según necesites.

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

#### Importando el disco {#importing-disk}

Ahora vamos a importar el archivo QCOW2 provisto por Juniper.

{% highlight shell %}
VMNAME=apstra-os-03.ipa.<my TLD>
VMID=$(qm list|grep ${VMNAME}|awk '{ print $1 }')
STORAGE=local-zfs

qm disk import ${VMID} aos_server_4.2.0-236.qcow2  ${STORAGE}
qm set ${VMID} -scsi0 ${STORAGE}:vm-${VMID}-disk-1
qm set ${VMID} --boot order=scsi0
{% endhighlight %}

#### Disco adicional {#additional-disk}

Según la documentación, el disco del sistema operativo es de solo 80GB y opcionalmente se puede agregar un segundo disco de 80GB. Dado que no es costoso y que no voy a usar nodos worker adicionales, voy a agregar el segundo disco.

{% highlight shell %}
VMNAME=apstra-os-03.ipa.<my TLD>
VMID=$(qm list|grep ${VMNAME}|awk '{ print $1 }')
STORAGE=local-zfs

qm set ${VMID} --scsi1 ${STORAGE}:80
# we start the VM
qm start ${VMID}
{% endhighlight %}

### Appliance ZTP {#ztp-appliance}

DHCP y TFTP no son tan exigentes, alcanza con 2 vCPUs y 4GB de RAM. 

La red se sirve mediante el bridge por defecto y el almacenamiento mediante el repositorio ZFS local. Las opciones se explican solas, ajústalas según necesites.

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

#### Importando el disco {#importing-disk-1}

Ahora vamos a importar el archivo QCOW2 provisto por Juniper.

{% highlight shell %}
VMNAME=apstra-ztp-03.ipa.<my TLD>
VMID=$(qm list|grep ${VMNAME}|awk '{ print $1 }')
STORAGE=local-zfs

qm disk import ${VMID} apstra-ztp-4.2.0-34.qcow2  ${STORAGE}
qm set ${VMID} -scsi0 ${STORAGE}:vm-${VMID}-disk-1
qm set ${VMID} --boot order=scsi0
qm start ${VMID}
{% endhighlight %}

## Configuración inicial {#initial-configuration}
### Configuración de AOS {#aos-setup}

1. Busca la IP del appliance en los leases de tu DHCP y conéctate por SSH con admin/admin.
2. En el primer login define una nueva contraseña, como se te pide.
3. En el asistente forzado, define también la contraseña de la UI de Apstra como se propone. Cancela en el menú principal después de configurar la contraseña.
4. Cambia el hostname por algo que tenga sentido en tu entorno. Con el usuario admin ejecuta:
{% highlight shell %}
sudo aos_hostname apstra-os-03.ipa.<my TLD>
{% endhighlight %}
{:start="5"}
3. Ajusta la zona horaria para que coincida con tu entorno.
{% highlight shell %}
sudo timedatectl set-timezone <my TZ>
{% endhighlight %}
{:start="6"}
1. Como admin, actualiza el sistema operativo. Lo más probable es que Juniper te diga que esto no está soportado. El único problema que tuve en el pasado fue que 4.1.0 se rompió porque había una librería de Juniper a nivel de sistema que rompió una aplicación en contenedor (a ver si se entiende) y hubo que arreglarlo con una actualización manual de dependencias. Ha sido impecable con 4.1.2 y ahora con 4.2.0; se mencionarán archivos de pam.d, conserva los archivos modificados localmente.
{% highlight shell %}
sudo apt update
sudo apt upgrade -y
{% endhighlight %}
{:start="7"}
1. Instala el agente invitado de QEMU
{% highlight shell %}
sudo apt install -y qemu-guest-agent
{% endhighlight %}
{:start="8"}
1. Reinicia después de la actualización completa del sistema
sudo shutdown -r now

### Configuración del appliance ZTP {#ztp-appliance-setup}

1. Busca la IP del appliance en los leases de tu DHCP y conéctate por SSH con admin/admin.
2. Define el hostname

 {% highlight shell %}
sudo hostnamectl set-hostname apstra-ztp-03.ipa.<my TLD>
sudo sh -c 'echo "127.0.0.1 apstra-ztp-03.ipa.<my TLD>" >> /etc/hosts'
{% endhighlight %}
{:start="3"}
3. Ajusta la zona horaria para que coincida con tu entorno.
{% highlight shell %}
sudo timedatectl set-timezone <my TZ>
{% endhighlight %}
{:start="4"}
1. Limpia la estructura de configuración desordenada: por alguna razón, a los de Juniper les pareció buena idea crear un directorio donde debería haber un archivo y eso rompe el proceso de actualización de Ubuntu. Lo limpiamos (¿qué pasa, Juniper?!)
 {% highlight shell %}
sudo rmdir /etc/udev/rules.d/70-persistent-net.rules
{% endhighlight %}
{:start="5"}
1. Actualiza el sistema operativo. Otra vez, probablemente Juniper te diga que no está soportado.
{% highlight shell %}
sudo apt update
sudo apt upgrade -y
{% endhighlight %}
{:start="6"}
7. En la Web UI de Apstra, crea un usuario con el rol device_ztp. Lo usaremos en el siguiente paso.
8. De vuelta en el appliance ZTP, configura la aplicación para que reporte al servidor AOS. Por alguna razón no funciona con FQDN sino solo con IP.
{% highlight shell %}
cat > /containers_data/status/app/aos.conf <<EOF
{
   "ip": "<your-aos-ip>",
   "user": "<your ztp user>",
   "password": "<the super secure password>"
}
EOF
{% endhighlight %}
{:start="8"}
1. Instala el agente invitado de QEMU
{% highlight shell %}
sudo apt install -y qemu-guest-agent
{% endhighlight %}
{:start="9"}
7. Reinicia la máquina virtual
{% highlight shell %}
sudo shutdown -r now
{% endhighlight %}

## Migración desde 4.1.2 {#migration-from-412}

Si ya tienes un entorno funcionando, lo más probable es que quieras migrar toda la configuración a tu nueva instalación; hay un script que debes ejecutar en el nuevo servidor Apstra.

Ten en cuenta que el script fallará si hay cambios sin confirmar (commit) o si los dispositivos no son alcanzables. Asegúrate de que el estado en ejecución del entorno de origen esté limpio (sin errores).

{% highlight shell %}
aos_import_state --ip-address apstra-os-02.ipa.<my TLD> --username admin
{% endhighlight %}

Nota: 
- La migración de la configuración también reemplazaría la contraseña de la web UI con la configuración del servidor original.
