---
title: "vSAN ESA en ESXi sobre PVE"
description: "Clúster vSAN ESA anidado con fines de prueba"
date: 2023-09-07 00:00:00 -0400
permalink: /es/homelab/2023/09/07/vsan-esa-on-esxi-over-pve.html
lang: es
categories:
  - virtualization
  - storage-backup
tags:
  - proxmox
  - esxi
  - vsan
  - nested-virtualization
---

## Un poco de contexto {#a-little-bit-of-context}

### vSAN OSA {#vsan-osa}
Una de mis mayores quejas como cliente respecto a la oferta SDDC de VMware es vSAN OSA. La primera vez que lo vi en acción, me pareció una respuesta "yo también" a [Nutanix](https://www.nutanix.com/mx/info/software-defined-storage), que introdujimos con éxito, creo que como primer cliente en Paraguay, alrededor de 2016 (si la memoria no me falla). 

Además, viniendo de un trasfondo de soluciones basadas en FibreChannel como [vMAX de EMC](https://www.youtube.com/watch?v=Zp3yMGlzZhM) y [VSP de Hitachi](https://knowledge.hitachivantara.com/Documents/Storage/VSP_G1X00_and_VSP_F1500/80-06-6x/Hardware_Guide/03_Hardware_architecture), era una venta realmente difícil en cuanto a funcionalidades (sin snapshots, sin tiering, sin replicación, etc.) y irse a clústeres de 20 nodos solo porque necesitábamos capacidad para bases de datos Oracle enormes no tenía sentido (no es costo-efectivo)

Otra forma de verlo: si comparas vSAN OSA en vSphere con otras soluciones que sirven a Xen o KVM, le falta flexibilidad:
- un único pool por clúster
- un único tipo de disco
- el disco de caché como punto de falla importante

Cuando no había ESXi a la vista, simplemente íbamos con cualquier otra alternativa como [CEPH](https://docs.ceph.com/en/latest/architecture/) o [MooseFS](https://moosefs.com/blog/architecture/) (nada de [GlusterFS](https://docs.gluster.org/en/main/Quick-Start-Guide/Architecture/), nadie te quiere....)

En el lado positivo, es un punto de entrada interesante hacia mejores alternativas para quienes están tecnológicamente atrasados: piensa en iSCSI con 1GbE o CIFS/SMB3 servido desde tu servidor de archivos Windows Server :s

En definitiva, tiene sentido si:
- eres una empresa VMware con equipo(s) de infraestructura muy limitado(s)
- quieres una forma rápida de introducir una plataforma de virtualización
- no hay un Storage + SAN centralizado para empezar
- tus necesidades de almacenamiento no son desproporcionadas en comparación con el cómputo
- no necesitas servicios avanzados de almacenamiento como tomar snapshots de los discos de tu base de datos Oracle de producción de 40TB en vivo (10*4TB + ASM) para presentarlos a una instancia secundaria de reportes.

### vSAN ESA {#vsan-esa}
La primera vez que oí hablar de [vSAN ESA](https://core.vmware.com/blog/introduction-vsan-express-storage-architecture) fue en el evento VMware Explore 2022. No es perfecto, pero es un paso en la dirección correcta.

Para que quede claro, estoy bastante contento con la evolución. :)

Asegúrate de ver la grabación bajo demanda de la sesión de VMware Explore 2022 [Get to Know the Next-Generation of vSAN Architecture](https://www.vmware.com/explore/video-library/video-landing.html?sessionid=1663909090011001QAvr&videoId=6315818080112) para entender todas las bondades.

## Volviendo a nuestro entorno anidado en Proxmox. {#going-back-to-our-proxmox-nested-environment}

Con ese contexto, te recomiendo explorar los cambios de la nueva arquitectura.

Si quieres ensuciarte las manos, vSAN ESA se puede desplegar en nuestro entorno anidado de ESX-on-KVM/Proxmox. 

Por supuesto:
- no estará soportado, pero te permitirá jugar con él
- las pruebas de rendimiento reales requerirán un entorno físico debidamente soportado

Habrá advertencias, porque no cumplimos ninguna [configuración soportada](https://kb.vmware.com/s/article/90343), notablemente:
- interfaces de 25GbE
- controladores NVMe
- 512GB de RAM por nodo

### Controlador de discos {#disk-controller}

En un mundo ideal, deberíamos usar un controlador NVMe, que QEMU soporta, pero [Proxmox aún no soporta](https://bugzilla.proxmox.com/show_bug.cgi?id=2255). Dado ese escenario, vamos con el controlador SATA por defecto.

### Aprovisionamiento de los discos {#provisioning-of-the-disks}

Para esta prueba, tomaremos 3 instancias de ESXi anidadas y agregaremos a cada una 3 discos de 100GB emulando SSD. Puedes usar más discos y/o más grandes, el cielo (¿tu billetera?) es el límite.

{% highlight shell %}
STORAGE=dstore01
for VM in esxi01 esxi02 esxi03
do
    # We get the ID to operate on the VM
    VMID=$(qm list|grep ${VM}|awk '{ print $1 }')
    # Adding disks, emulating SSD
    qm set ${VMID} --sata3 ${STORAGE}:100,format=qcow2,ssd=1,discard=on \
        --sata4 ${STORAGE}:100,format=qcow2,ssd=1,discard=on \
        --sata5 ${STORAGE}:100,format=qcow2,ssd=1,discard=on
done
{% endhighlight %}

## Configuración de vSAN {#vsan-setup}

Puedes configurar el clúster vSAN como lo harías normalmente, durante el despliegue de vCenter o después de tenerlo funcionando.

La primera advertencia que verás es que las NICs no están soportadas (se exigen 25GbE). Puedes seguir adelante de todas formas.

{% include image.html url="/assets/img/2023-09-07-nic-speed-warning.png" description="Imagen 1 - Advertencia de NIC" alt="Advertencia de NIC" width=1365 height=907 %}

Si sigues adelante, los discos se marcarán como incompatibles. Simplemente reclámalos manualmente.

{% include image.html url="/assets/img/2023-09-07-incompatible-disk-warning.png" description="Imagen 2 - Disco marcado como no compatible" alt="Disco marcado como no compatible" width=1817 height=683 %}

{% include image.html url="/assets/img/2023-09-07-disk-claiming.png" description="Imagen 3 - Reclamo manual" alt="Reclamo manual" width=1800 height=812 %}

## Resultado {#outcome}

Después de unos minutos, deberías tener tu clúster vSAN de ESXi anidado sobre PVE, funcional pero no soportado.

¡Que te diviertas!
