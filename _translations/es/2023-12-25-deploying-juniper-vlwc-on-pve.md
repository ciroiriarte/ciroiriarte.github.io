---
title: Despliegue de Juniper vLWC en PVE
description: "Recorrido por el análisis y el despliegue de un Juniper Virtual Lightweight Collector para la funcionalidad de \"call home\""
date: 2023-12-25 00:00:00 -0300
permalink: /es/datacenter/networking/2023/12/25/deploying-juniper-vlwc-on-pve.html
lang: es
categories:
  - networking
  - virtualization
tags:
  - juniper
  - junos
  - proxmox
---

## Intro {#intro}

Como con cualquier infraestructura crítica, los proveedores de tecnología ofrecen una función de "call-home" para sus productos. Desde hace más de una década (al menos que yo sepa), proveedores de storage como Hitachi o EMC ofrecen una solución que permite al proveedor conectarse a los sistemas que son tuyos para que los departamentos de soporte/asistencia trabajen directamente en ellos, en lugar de decirte por teléfono qué hacer. Otras funciones esperadas incluyen abrir un ticket proactivo ante una falla de hardware, extraer/subir logs o inventariar la base instalada.

Esta funcionalidad de call-home normalmente se entrega como un software que corre en un appliance dedicado/físico, como un software a instalar en una instancia de un Sistema Operativo de propósito general (Windows Server, SLES/RHEL/OEL/Debian) o, hoy en día, un appliance virtual pre-empaquetado.

Implementar una funcionalidad así siempre es buena idea, ya que permite al equipo de soporte del proveedor responder más rápido cuando hay fallas.

<!--more-->

## La necesidad {#the-need}

El equipo de soporte de Juniper se nos acercó ofreciendo un appliance WLC que daría capacidades de call-home y supervisaría nuestra base instalada. Este appliance es parte de su iniciativa Juniper Support Insights (JSI).

Uno de esos appliances físicos va en camino a uno de nuestros sitios. Mientras tanto, estoy a cargo de un despliegue de laboratorio que podría beneficiarse del soporte rápido y las capacidades de inventario. Revisando más el tema, el equipo de Juniper mencionó que existe una versión virtual del appliance que se liberó recientemente.

La [documentación](https://www.juniper.net/documentation/us/en/software/jsi/vlwc-deploy/topics/topic-map/install-verify-vlwc.html) formal para entornos vSphere es bastante directa y puedes seguirla tal cual si trabajas en un entorno soportado. En mi caso, el entorno "sidecart" de soporte del laboratorio no tiene VMware vSphere, sino Proxmox VE.

Voy a desplegar vLWC en Proxmox VE para supervisar los switches QFX gestionados por Apstra y los switches EX que componen la red OOBM de los propios QFX.

## Here be dragons. {#here-be-dragons}

{% include image.html url="/assets/img/2023-12-25_1570-theatrum-orbis-terrarum-map-monsters.jpg" link="https://education.nationalgeographic.org/resource/here-be-dragons/" description="Imagen 1 - Mapa de monstruos del Theatrum Orbis Terrarum, 1570" width=860 height=580 %}

Como advertencia, debo señalar que la configuración que estoy a punto de ejecutar y compartir contigo no está soportada por Juniper, y tu Service Manager te mirará mal, te gritará o directamente te ignorará (según el tipo de relación que tengas) si alguna vez pides ayuda para desplegar vLWC en KVM. En nuestro caso, ¡le doy la bienvenida a Alejandro para el soporte administrativo!.

Recuerda también que "no soportado" no significa que no sea técnicamente posible. Solo significa que estás por tu cuenta. Espero que en algún momento se agregue soporte para Proxmox y/o KVM.

Sí, voy a obtener soporte a través de un appliance "no soportado". ¿Califica como oxímoron?

## Arquitectura de red {#network-architecture}
### Entorno de laboratorio sidecart {#lab-sidecart-environment}
En el laboratorio tenemos un entorno con el conjunto habitual de proveedores y tecnologías con las que trabajamos. Esa configuración incluye una red IP Fabric EVPN/VXLAN que da servicio a varios clientes. Se espera que esa red y las plataformas de los clientes se reinstalen o reorganicen en cualquier momento.

Para ofrecer algunos servicios esenciales estables, armamos un pequeño entorno paralelo con algunos switches y servidores PVE para correr los elementos que deben estar disponibles en todo momento:

- Plataforma de acceso remoto
- Servicios de autenticación
- Herramientas relacionadas con seguridad
- Herramientas de monitoreo
- Soluciones de firmware y hardware

Con este entorno "sidecart", sin importar qué haya que reorganizar en el entorno principal, nunca perderemos capacidad de administración.

Para el alcance de esta discusión, el entorno lógico se ve más o menos así:

{% include image.html url="/assets/img/2023-12-25_lab-environment.svg" description="Imagen 2 - Entorno de red de gestión relacionado" alt="Vista general de las redes del laboratorio" %}

Físicamente, el sidecart es solo un par de switches Cisco Nexus en stack para dar servicios L2 redundantes de 1GbE/10GbE, y la red OOBM es un par de switches Juniper EX que dan conectividad de 1GbE a los switches y a las placas de servidor con IPMI.

Lógicamente, la configuración es bastante elaborada y ofrece cosas como control de acceso y segmentación de red a través de OPNSense, que aporta capacidades L3 y de filtrado. Necesitamos que los usuarios se autentiquen con usuario/contraseña + OTP, y luego llegamos a los Jump hosts usando Guacamole:

{% include image.html url="/assets/img/2023-12-25_lab-environment-flows.svg" description="Imagen 3 - Flujo de acceso remoto" alt="Acceso remoto" %}

Mi expectativa natural era desplegar el appliance de call-home junto a otros appliances de soporte como Apstra o LibreNMS.

{% include image.html url="/assets/img/2023-12-25_lab-environment-plus-vlwc.svg" description="Imagen 4 - Agregando vLWC al cuadro" alt="vLWC en el cuadro" %}

Esto es relevante para la siguiente sección.

### Topología de red requerida {#required-network-topology}

Revisando la [guía de despliegue](https://www.juniper.net/documentation/us/en/software/jsi/vlwc-deploy/topics/concept/system-requirements.html), puedes ver que exige 3 interfaces de red:

Interfaz|Dirección IP soportada|Rol
---|---|---
Internal|Dirección IPv4 o IPv6|Se usa para la conexión a los switches a monitorear. La ruta por defecto también va aquí.
External|Solo dirección IPv4|Se usa para conectarse a la Estrella de la Muerte (el call-home propiamente dicho)
Management|Solo dirección IPv4|Se usa para el acceso al captive portal (portal web que presenta el appliance mostrando su estado)

Podríamos intentar cumplir y calzar a la fuerza los requisitos del appliance en nuestro entorno:

{% include image.html url="/assets/img/2023-12-25_lab-environment-plus-vlwc-forced-compliance.svg" description="Imagen 5 - Cumplimiento forzado" alt="vLWC en el cuadro" %}


No me deja tranquilo: unas VMs conectadas a segmentos distintos que solo deberían interactuar a través del firewall no era una opción en nuestro caso.

### Análisis del appliance: prueba y error {#appliance-analysis-trial--error}

Hice varias corridas del despliegue en KVM, en el vacío, para validar qué pasa con la configuración de red y analizar qué se necesita para desplegarlo con una sola interfaz.

Te ahorro los detalles, pero el resumen de los hallazgos es:

#### **Primera corrida:** 3 redes con DHCP (internal + external + management) {#first-run-3-networks-with-dhcp-internal--external--management}
*"int"* conserva la ruta por defecto  
*"ext"* tiene rutas estáticas para llegar a la Estrella de la Muerte (JNI)  
*"cap"* se usa para el captive portal (página de estado del appliance)

Las rutas estáticas mencionadas (por si tienes curiosidad, esos segmentos pertenecen a AWS y DigitalOcean):

```
35.71.174.221 via <ext segment gateway> dev ext 
35.83.44.146 via <ext segment gateway> dev ext 
52.223.32.79 via <ext segment gateway> dev ext 
54.149.98.110 via <ext segment gateway> dev ext 
54.149.222.60 via <ext segment gateway> dev ext 
68.183.248.21 via <ext segment gateway> dev ext 
138.197.235.241 via <ext segment gateway> dev ext 
```
**Primera conclusión:** Es posible que tengamos que manipular el appliance para evitar que instale las rutas estáticas, a menos que la instalación de las rutas estáticas falle silenciosamente por la falta de la interfaz EXT.

El binding de los servicios SSHD y Captive Portal no está limitado a ninguna interfaz en particular. 

{% highlight shell %}
root@ggc-lnx:~# lsof -n -sTCP:LISTEN -i :443
COMMAND     PID USER   FD   TYPE DEVICE SIZE/OFF NODE NAME
docker-pr 20982 root    4u  IPv4 106963      0t0  TCP *:https (LISTEN)
docker-pr 20994 root    4u  IPv6 107636      0t0  TCP *:https (LISTEN)
root@ggc-lnx:~# lsof -n -sTCP:LISTEN -i :22 
COMMAND PID USER   FD   TYPE DEVICE SIZE/OFF NODE NAME
sshd    543 root    3u  IPv4  17619      0t0  TCP *:ssh (LISTEN)
sshd    543 root    4u  IPv6  17621      0t0  TCP *:ssh (LISTEN)
{% endhighlight %}

**Segunda conclusión:** no necesitamos meternos con la configuración de binding de los servicios, todos escuchan en todas las interfaces.

Así que el comportamiento de "no responder en EXT" muy probablemente debería venir de reglas de firewall, excepto que no (no existe ninguna regla de firewall que limite las solicitudes SSH entrantes a una interfaz dada), ese comportamiento fue una construcción de mi imaginación y no hay mención de él en la documentación. 

Mi prueba de ssh se hizo desde un cliente en la misma subred que aloja la interfaz EXT. Mi suposición a ojo es que cualquier otro intento de conexión de clientes remotos desde Internet debería fallar porque el gateway por defecto está instalado en INT. 

De todos modos, chicos, no pongan el appliance directamente conectado a Internet sin filtros de entrada si pueden evitarlo.

**Tercera conclusión:** no necesitamos meternos con la configuración del firewall.

**Cuarta conclusión:** La siguiente captura muestra cómo se ve un appliance sano.

{% include image.html url="/assets/img/2023-12-25_status-deployment-test-3if.png" description="Imagen 6 - Estado del appliance con la disposición de red soportada" alt="Estado del appliance" width=782 height=754 %}

#### **Segunda corrida:** configuración de 1 red con DHCP (internal) {#second-run-1-network-setup-with-dhcp-internal}
*"int"* conserva la ruta por defecto, da acceso al captive portal (página de estado del appliance)  
*"ext"* se reporta con estado fallido  

**Quinta conclusión:** Aunque la página de estado muestra un "Connection Status" con error para "External Network", puedes ver que igual tenemos "Juniper Cloud Connected" y "Cloud Provisioned". Mi interpretación es que tenemos un error porque no hay una interfaz EXT que se pueda configurar, pero es cosmético, ya que tenemos acceso a Internet usando INT con la ruta por defecto.

{% include image.html url="/assets/img/2023-12-25_status-deployment-test-1if.png" description="Imagen 6 - Estado del appliance con una sola interfaz" alt="Estado del appliance" width=775 height=767 %}

También puedo confirmar que, tras revisar el appliance a nivel de SO, no hay rutas estáticas. No se necesitan ajustes para que un despliegue con una sola interfaz se conecte a JSI.

## El appliance {#the-appliance}
### Primeros pasos administrativos. {#first-administrative-steps}

Tienes que pedirle dos cosas a tu equipo de soporte de Juniper:
- Acceso a Juniper Support Insights para solicitar el appliance
- Que configuren los permisos adecuados para gestionar/usar el appliance. Tenemos una infinidad de cuentas de soporte y algo no se configuró bien para mi cuenta en JSI.

### Cómo solicitar el appliance. {#how-to-request-the-appliance}

1. Una vez que tengas los permisos correctos para tu usuario, ve al [Juniper Support Portal](https://supportportal.juniper.net/)
2. Solicita el appliance a través del portal web.
{% include image.html url="/assets/img/2023-12-25_request_appliance_00.png" description="Imagen 7 - Acceder a la sección de collectors" alt="Sección de collectors" width=887 height=368 %}
  
{% include image.html url="/assets/img/2023-12-25_request_appliance_01.png" description="Imagen 8 - Haz clic en &quot;Request Virtual Lightweight Collector&quot;" alt="Solicitud" width=1433 height=217 %}
  
{% include image.html url="/assets/img/2023-12-25_request_appliance_02.png" description="Imagen 9 - Haz clic en &quot;Fill-in and submit form&quot;" alt="Solicitud" width=1494 height=775 %}

{:start="3"}
3. En menos de una hora, deberías recibir un correo de *do_not_reply@juniper.net* con un enlace para descargar el appliance. El archivo se purga en 7 días, después de los cuales tendrías que volver a solicitar el appliance.

## Despliegue {#deployment}

### ¿Qué recibes de Juniper? {#what-are-you-receiving-from-juniper}

Cuando descargas el appliance del sitio de soporte de Juniper, obtienes un archivo OVA con un nombre similar a vLWC-${VERSION}-$(SERIAL_NUMBER).ova. En mi caso fue la versión 2.3.26.

Un archivo OVA es básicamente un archivo ZIP con una imagen de disco VMDK y un archivo OVF con la definición de la máquina virtual a crear, incluyendo metadata y la definición de lo que el usuario debe ingresar durante el rollout (omitiremos el archivo de manifiesto para efectos de esta discusión).

El VMDK aparentemente es genérico para todos los clientes; el archivo OVF incluye el número de serie específico de tu despliegue y hay que incorporarlo durante la instanciación/rollout.

### Configuración inicial {#initial-setup}

Con la personalización de OVF disponible vía vSphere + VMware Tools, se pasan algunos parámetros a la VM en el momento de la instanciación, pero eso no está soportado por Proxmox VE. Proxmox VE + cloud-init podría dar capacidades similares, pero el appliance vLWC no lo soporta actualmente.

{% include image.html url="/assets/img/2023-12-25_missmatch.jpg" description="Imagen 10 - Capacidades de autoconfiguración, Proxmox VE a la izquierda, Juniper vLWC a la derecha &quot;" alt="Desajuste" width=1200 height=630 %}

Tendríamos que modificar el disco original antes de importarlo a la máquina virtual. Voy a intentar hacer la menor cantidad de modificaciones posible.

- Cambios requeridos
1. La configuración de red viene preconfigurada en el appliance para DHCP; como tenemos DHCP en el entorno sidecart, la dejaremos tal cual. Otros entornos podrían necesitar direccionamiento estático, fuera de alcance por ahora.
2. En cualquier escenario, un cambio obligatorio para el appliance sería introducir el número de serie para que reporte correctamente a JSI. Requiere dos entradas: una entrada en texto plano que recuperaremos del nombre del archivo descargado y una entrada cifrada que debemos recuperar del archivo OVF.

- Cambios deseables
1. Ajustaremos el hostname por el bien de un inventario correcto. He visto los logs del appliance reportando a casa el hostname como nombre de producto y versión de producto (muchachos de Juniper, para eso no sirve un hostname); por ahora no parece afectar la funcionalidad, pero lo monitorearé y haré rollback si hace falta.
2. Zona horaria. El appliance viene preconfigurado con la zona horaria UTC; la voy a ajustar a la nuestra. Habrá que monitorear y hacer rollback si eso afecta algo del lado de JSI.
3. QEMU Agent. Da cierta integración con PVE para ayudar en la gestión de la VM.
4. Instalar mi llave pública para el login de root, ayuda con el troubleshooting (ya sé, se supone que no debo usar root en este appliance, igual que se supone que no debo desplegarlo en PVE/KVM 🙂)

***
**Actualización 1**: Me contactó alguien que parece formar parte del equipo de operaciones de JSI; pidió amablemente que revirtiera el cambio de hostname porque les rompe cosas.

Como tiro largo, estoy agregando esto como pedido adicional para el PLM.  

***


Copia el archivo OVA a tu host PVE (scp es tu amigo) y sigue el procedimiento de abajo.

1. Primero, tenemos que anotar el número de serie en las dos representaciones que vamos a necesitar.

{% highlight shell %}
# prepare the working directory
mkdir -p import/juniper
cd import/juniper
# at this point, copy the OVA file via SCP.
# verify file existance
ls -l vLWC-2.3.26-<serial>.ova
-rw-r--r-- 1 ciro.iriarte ipausers 2466766848 Dec 19 17:01 vLWC-2.3.26-<serial>.ova
# We extract the content of the ZIP file
mkdir vLWC-2.3.26-<serial>
tar -C vLWC-2.3.26-<serial>/ -xf vLWC-2.3.26-<serial>.ova
cd vLWC-2.3.26-<serial>/

# Recover the un-encrypted serial number from the filename and take note of the output of this command
basename -s .ova $(ls -1 ~/import/juniper/*ova)| awk -F "-" '{ print $NF }'

# Recover the encrypted serial number from the OVF file and take note of the output of this command
grep --color serial_number ~/import/juniper/vLWC-2.3.26-<serial>/vLWC-2.3.26-<serial>.ovf |awk '{ print $6 }'|cut -f 2 -d '"'

{% endhighlight %}

{:start="2"}
2. Montamos el sistema para modificarlo
{% highlight shell %}
# Make sure you start in the same directory we were working before. We move to the directory containing the disk image.
cd vLWC-2.3.26-<serial>/

# Convert from VMDK to RAW
qemu-img  convert vLWC-2.3.26-<serial>-disk1.vmdk vLWC-2.3.26-<serial>-disk1.raw

# Bind disk to loopback device
losetup -f -P vLWC-2.3.26-<serial>-disk1.raw
# Confirm binding
losetup -l 

# Create a mount point for the vLWC system
mkdir -p /mnt/loop-root
# Mount the first partition
MYLOOP=$(losetup -l|grep vLWC | awk '{ print $1 }')
mount ${MYLOOP}p1 /mnt/loop-root/
mount -o bind /dev /mnt/loop-root/dev/
mount -o bind /proc /mnt/loop-root/proc/
chroot /mnt/loop-root/
{% endhighlight %}

{:start="3"}
3. Como se mencionó, tenemos que definir el número de serie correcto. Este sería el único cambio obligatorio
{% highlight shell %}
# Define variables with serial data for your appliance
MYSERIAL="your plain text serial number"
MYSERIALENCRYPTED="your encrypted serial number"

# Set encrypted serial parameter
echo $(cat /opt/jsas/etc/vlwc-status.json | jq --arg val "$MYSERIALENCRYPTED" '.properties.serial_number = $val') > /opt/jsas/etc/vlwc-status.json
# Set plain text serial
echo -n "$MYSERIAL" > /home/jsas/nfxserialnum

{% endhighlight %}

{:start="4"}
4. Cambios deseables. Los haces mientras sigues **dentro** del entorno chroot. Si quieres, puedes meter todo el bloque en un script.

{% highlight shell %}

##
# QEMU agent
##

# Temporary adjust name resolution to allow package installation from Internet
MYDNS="x.y.z.w"
mv /etc/resolv.conf{,.orig}
echo "nameserver $MYDNS" > /etc/resolv.conf
# We install QEMU agent
apt install qemu-guest-agent
# Restore original DNS resolution config
mv /etc/resolv.conf{.orig,}

##
# Hostname. We don't do this anymore until Juniper releases an update that moves the appliance version validation from the hostname.
##
#NO# MYHOSTNAME="short.TLD"
# We backup original setup
#NO# cp -p /etc/hostname{,.orig}
# We define new hostname
#NO# echo $MYHOSTNAME > /etc/hostname

# In case you did change the hostname, the rollback would be:
# mv /etc/hostname{,.mine}
# mv /etc/hostname{.orig,}
# hostname $(cat /etc/hostname)

##
# Timezone
##

# Set your preferred timezone. You can get a list from timedatectl list-timezones
timedatectl set-timezone <Region>/<Country>

##
# SSH key for root
##

# Create the missing directory
mkdir ~/.ssh
# Add your public key to the trusted keys
YOURPUBKEY="key-type your-full-public-key-should-go-here key-alias"
echo "$YOURPUBKEY" >> ~/.ssh/authorized_keys

{% endhighlight %}

{:start="5"}
5. Desmontamos la imagen y desvinculamos el dispositivo

{% highlight shell %}
# we exit the chroot
exit
# umount filesystems
umount /mnt/loop-root/dev /mnt/loop-root/proc /mnt/loop-root
# unbind device
losetup -d $MYLOOP
{% endhighlight %}

En este punto, la imagen de disco contiene la configuración requerida para tu sitio/instancia.

### Creación de la VM {#vm-creation}

Para una solución soportada en vSphere, el archivo OVF se importa en vCloud Director o vCenter. Incluye la definición de la VM (cantidad y tipo de CPU, RAM, discos y adaptadores de red).

No podemos usar el archivo OVF para Proxmox VE; debería funcionar, pero en la práctica encontré algunos problemas de formato.

Entra por SSH a tu máquina PVE y crea un script para desplegar la VM:

{% highlight shell %}
root@pve01:~/import/juniper# cat > import-vlwc.sh<<'EOF'
#!/bin/bash
# We set the bridge & the VLAN we need to integrate de VM to.
BRIDGE=vmbr0
VLAN=4089
# Storage destination for the appliance to live in
STORAGE=local-zfs
# Source disk image
DSK=vLWC-2.3.26-<serial>/vLWC-2.3.26-<serial>-disk1.raw

# We need the next VM ID available
NEWVM=$(pvesh get /cluster/nextid)
# Proper VM name
VMNAME=jsi-vlwc01.<my-TLD>

# We create the VM without disks. 6 vCPU + 16GB for up to 10k devices, most probably you can live with less resources.
qm create $NEWVM --name $VMNAME --bios seabios --machine q35 \
--numa 1 --sockets 1 --cores 6 \
--scsihw virtio-scsi-pci \
--memory 16384 \
--agent enabled=1

# We add the disk we have prepared, and attach it to the VM.
qm importdisk $NEWVM $DSK $STORAGE
qm set $NEWVM -scsi0 ${DISK} ${STORAGE}:vm-${NEWVM}-disk-0
# Boot device at BIOS
qm set $NEWVM --boot order=scsi0

# We add NIC with the correct VLAN mapping
qm set $NEWVM \
--net0 model=virtio,bridge=${BRIDGE},firewall=1,tag=${VLAN}

# We start the VM
qm start
EOF

# Allow the script to be executed
root@pve01:~/import/juniper# chmod +x import-vlwc.sh

# Create VM
root@pve01:~/import/juniper# ./import-vlwc.sh
{% endhighlight %}

Después de un par de minutos, deberías poder visitar la vista web del captive portal a través del FQDN del appliance (suponiendo que tengas una integración DHCP+DNS adecuada) o su dirección IP.

Usa el número de serie en texto plano para iniciar sesión y busca "Juniper Cloud Connected" + "Cloud Provisioned" para asegurarte de que está en línea.


## Lista de deseos para el PLM {#wishlist-for-the-plm}

Por si pasa por aquí un Product Owner del appliance Juniper vLWC :), recomendaría incluir lo siguiente en el backlog:

### 1- Soporte para una configuración de una sola interfaz {#1--support-for-a-single-interface-setup}

Entiendo perfectamente la configuración de 3 interfaces para un appliance físico que está colocalizado con un MX960 solitario en un sitio remoto olvidado de Dios. Obtienes:
- Un puerto "trusted" que está conectado a una red OOBM que sirve a varios NEs o directamente al puerto OOBM de un router solitario.
- Un puerto "outside" que te da acceso a Internet, probablemente proveniente de un NE del lado del ISP y en el que no se debería confiar (sin servicios como SSH escuchando).
- Un puerto "management" que daría acceso al appliance a un ingeniero en sitio, probablemente conectado directamente a su laptop.

Mi suposición poco informada es que el appliance virtual básicamente siguió un enfoque de "meter a la fuerza en una VM lo que teníamos en la versión [appliance físico](https://www.juniper.net/documentation/us/en/hardware/lwc-hardware-guide/lwc/topics/concept/lwc-description.html)".

Una máquina virtual muy probablemente se desplegará en un cómodo datacenter TIER-algo, en un cluster de virtualización como corresponde, con una configuración lógica muy elaborada para gestión y monitoreo, con integraciones L3 hacia los destinos que se requieran y servicios como filtrado/segmentación fuera del appliance.

El pedido sería: por favor, soporten/permitan una configuración de "interfaz única" como alternativa a la de 3 puertos. Hoy funciona tal cual, salvo por los errores relacionados con EXT en la página de estado.

### 2- Una distribución Linux más nueva {#2--newer-linux-distribution}

A partir de vLWC-2.3.26, el appliance se basa en Ubuntu 18.04.6 LTS, que ya está [fuera del Standard Support desde junio de 2023](https://wiki.ubuntu.com/Releases). Solo los suscriptores de soporte Ubuntu Pro obtendrán versiones de parches mínimas, y tras una verificación rápida puedo decir que eso no está disponible en el appliance desplegado (¿quizás incluso con una versión de openssl con bugs?):

{% highlight shell %}
root@ggc-lnx:~# pro status
Failed to access URL: https://contracts.canonical.com/v1/resources?architecture=amd64&kernel=4.15.0-212-generic&series=bionic&virt=kvm
Cannot verify certificate of server
Please check your openssl configuration.
{% endhighlight %}

Las instancias de distribuciones Linux viejas y las implicancias de seguridad para un entorno dado son un tema trillado. Resumiría el pedido así: toca un refresh del SO y Ubuntu 22.04.3 LTS está a su disposición. No, "eventualmente re-empaquetaremos una nueva versión del appliance con los parches aplicados y tendrás que re-desplegar" no es aceptable

### 3- Soporte para PVE/KVM {#3--support-for-pvekvm}

No todas las tiendas Juniper corren VMware vSphere del lado de cómputo, y si lo hacen, puede que no sea la elección para todos y cada uno de los despliegues. Aunque agradezco el trabajo hecho en la preparación del archivo [OVF](https://www.dmtf.org/standards/ovf) para automatizar la configuración inicial, recomiendo fuertemente que su equipo invierta algo de tiempo en implementar soporte para [cloud-init](https://cloudinit.readthedocs.io/en/latest/) en el script de configuración inicial, que es el estándar de facto para desplegar appliances virtuales en entornos cloud (KVM on prem, vSphere, AWS, Azure, etc).

Algunas frutas al alcance de la mano:
- Los drivers de interfaz de red VirtIO ya están disponibles en el appliance (recomendados para KVM/QEMU, sin limitarse a VMXNET3). Usados en este despliegue.
- El QEMU agent se puede instalar fácilmente desde los repos de Ubuntu preconfigurados en el appliance (deseable, cubre parte de la funcionalidad de VMware Tools para KVM/QEMU). Usado en este despliegue.
- El agente cloud-init se puede instalar fácilmente desde los repos de Ubuntu preconfigurados en el appliance. No usado en este despliegue.

### 4- Permitir el cambio de hostname {#4--allow-for-hostname-change}

Debido a algunos requisitos/convenciones discutibles que tenemos, necesitamos asignar un hostname adecuado a la VM. Parece que se usa para el versionado del appliance, como se anotó un poco más arriba en el artículo.
- Hacemos coincidir el nombre de la VM y el hostname del SO para fines de inventario (consolidación y verificación cruzada de datos de varias herramientas).
- Parte de los controles SOX recomienda que se aplique una convención de nombres de hostname adecuada.
- El registro por DHCP actualiza los registros DNS; tener más de un appliance desplegado arruina esta integración automatizada.

Mi fuerte recomendación es que muevan el reporte de versión del appliance a una entrada de metadata propia en otro lugar, y dejen que el hostname sea un hostname.
