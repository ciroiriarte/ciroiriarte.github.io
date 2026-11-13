---
title: "Discos USB como cintas para Proxmox Backup Server (3/3): apuntar y hacer clic"
description: "La misma configuración de la parte 2, desde el panel de mhVTL Control y la interfaz web de PBS. Quedan unas pocas líneas de shell; todo lo demás son clics."
date: 2026-11-13 10:02:00 -0300
permalink: /es/datacenter/2026/11/13/pbs-usb-tapes-3-gui.html
lang: es
categories:
  - storage-backup
tags:
  - proxmox
  - pbs
  - tape
  - mhvtl
series: pbs-usb-tapes
series_part: 3
series_title: "Apuntar y hacer clic"
---

La [parte 2](/es/datacenter/2026/11/13/pbs-usb-tapes-2-cli.html) armó la configuración desde el shell. Esta parte lo hace con un mouse: [mhVTL Control](https://github.com/ciroiriarte/mhvtl-control) para la biblioteca virtual, y la interfaz web de PBS para el lado de las cintas. Si no leíste la [parte 1](/es/datacenter/2026/11/13/pbs-usb-tapes-1-why.html), ahí se explica por qué querrías tener trabajos de cinta de PBS sobre discos USB en primer lugar.

No todo tiene un botón todavía: instalar paquetes, activar las escrituras del panel y asociar el dock siguen requiriendo unas pocas líneas de shell.

<!--more-->

{% include series-nav.html %}

La configuración es la misma de antes: PBS 4.2 con un datastore llamado `store1`, un dock USB y discos para rotar. El entorno de prueba fue una VM Debian 13 recién instalada con mhVTL `1.8.0+git20261101.7e3a101` y mhVTL Control 0.6.0, ambos de mi [proyecto en OBS](https://build.opensuse.org/project/show/home:ciriarte:mhvtl).

## La parte de shell {#the-shell-part}

Agrega el repositorio, instala ambos paquetes y mantén fuera el driver `ch` del kernel. Pierde referencias de drives cada vez que aparece un changer, y PBS no lo necesita (la [parte 2](/es/datacenter/2026/11/13/pbs-usb-tapes-2-cli.html#install-mhvtl) tiene los detalles):

{% highlight shell %}
REPO=https://download.opensuse.org/repositories/home:/ciriarte:/mhvtl/Debian_13
install -d /etc/apt/keyrings
curl -fsSL -o /etc/apt/keyrings/mhvtl.asc $REPO/Release.key
echo "deb [signed-by=/etc/apt/keyrings/mhvtl.asc] $REPO/ /" \
    > /etc/apt/sources.list.d/mhvtl.list
apt-get update
# on a Proxmox kernel, use proxmox-default-headers instead:
apt-get install linux-headers-amd64 mhvtl mhvtl-control
echo "blacklist ch" > /etc/modprobe.d/mhvtl-no-ch.conf
# if this fails, ch is in use: reboot before going on
modprobe -r ch
{% endhighlight %}

El módulo del kernel se compila con DKMS para el kernel en ejecución. Si acabas de actualizar el kernel, reinicia primero.

El panel es de solo lectura de fábrica. Para editar hacen falta un token de API y un pequeño helper privilegiado que aplica los cambios:

{% highlight shell %}
TOKEN=$(openssl rand -hex 24); echo "$TOKEN"
echo "MHVTL_CONTROL_API_TOKEN=$TOKEN" >> /etc/mhvtl-control/mhvtl-control.env
chmod 600 /etc/mhvtl-control/mhvtl-control.env
systemctl enable --now mhvtl-control-apply.socket
systemctl enable mhvtl-control-apply-recover.service
systemctl enable --now mhvtl-control mhvtl.target
{% endhighlight %}

mhVTL Control escucha en `127.0.0.1:8080`, así que accede a través de un túnel SSH desde tu estación de trabajo:

{% highlight shell %}
ssh -L 8080:127.0.0.1:8080 root@pbs.example.com
{% endhighlight %}

Abre <http://localhost:8080>, haz clic en **Target…** y pega el token.

## Crear la biblioteca {#create-the-library}

El paquete trae dos bibliotecas STK de ejemplo. PBS no las puede ver: necesita un changer que reporte la página VPD 0x83 de INQUIRY, y los modelos STK que emula mhVTL no lo hacen. Así que agregamos una biblioteca con personalidad IBM.

En **Configuration**, haz clic en **New library…**:

- **Model:** IBM 03584. El asistente indica que "reports VPD page 83h", que es justamente lo que buscamos.
- **ID** 20, **serial** `MHV0020`, **4** slots de almacenamiento, **2** slots MAP (de correo).
- **Un drive:** IBM ULT3580-TD8, ID 21, serial `MHV002001`.
- **For:** Proxmox Backup Server. Esto activa una verificación de lo que necesita PBS.

{% include image.html url="/assets/img/2026-11-13-pbs-usb-m01-new-library.jpg" description="mhVTL Control: asistente New library, IBM 03584 con PBS seleccionado" width=1512 height=806 %}

Haz clic en **Stage library** y luego en **Check**. Check es una simulación: valida la nueva configuración y lista lo que el apply reiniciaría. Aquí son solo los dos daemons nuevos, y la verificación de PBS pasa:

{% include image.html url="/assets/img/2026-11-13-pbs-usb-m02-check-pbs.jpg" description="Check: la biblioteca 20 cumple los requisitos de PBS, solo se reinician vtllibrary@20 y vtltape@21" width=1512 height=806 %}

Haz clic en **Apply**. La biblioteca queda activa en unos segundos.

El asistente deja la compresión del drive desactivada, y está bien: los chunks de PBS ya vienen comprimidos. Las bibliotecas de ejemplo se quedan donde están (mira [Aristas sin pulir](#rough-edges)), así que sus drives aparecerán más adelante en la lista de drives de PBS.

## Asociar el dock {#bind-the-dock}

Este sigue siendo un paso de shell. Conecta un disco al dock, busca el nombre estable del puerto en `/dev/disk/by-path` (el de `usb-`, no el de `usbv3-`) y asócialo a la biblioteca 20. La segunda columna es el slot de correo previsto; por ahora el cartucho cae en el primero libre:

{% highlight shell %}
ls -l /dev/disk/by-path/ | grep -- -usb-
BAY=/dev/disk/by-path/pci-0000:00:01.0-usb-0:1:1.0-scsi-0:0:0:0
echo "20  1  $BAY" > /etc/mhvtl/mhvtl_raw_bays.conf
systemctl enable --now mhvtl-bay-monitor
{% endhighlight %}

El disco está en blanco, así que el monitor registra "not placed" y espera.

## Formatear el disco {#format-the-disk}

En **Raw Disk Dock**, el disco aparece como "NO MVTL (UNFORMATTED)". Haz clic en **Format…**, escribe el nombre del dispositivo para confirmar (esto **borra el disco**) y asígnale un código de barras. El sufijo `L8` lo convierte en medio LTO-8, que coincide con el drive:

{% include image.html url="/assets/img/2026-11-13-pbs-usb-m03-format.jpg" description="Raw Disk Dock: formatear el disco como cartucho USB001L8" width=1512 height=806 %}

El bay monitor detecta el nuevo cartucho de inmediato, y el **Library Rack** lo muestra en MAP 1. El panel del drive también muestra `encryption aes-gcm`: cuando PBS establece una clave, mhVTL cifra cada bloque con AES-256-GCM.

{% include image.html url="/assets/img/2026-11-13-pbs-usb-m04-rack-map.jpg" description="Library Rack: USB001L8 en el slot de correo" width=1512 height=806 %}

Pasa a la interfaz web de PBS, en `https://<pbs>:8007`.

## Agregar el changer y el drive {#add-the-changer-and-the-drive}

**Tape Backup → Changers → Add**. El desplegable de rutas lista solo el changer IBM (`scsi-MHV0020`). Las muestras STK son invisibles para PBS, como era de esperar. Lo llamé `usblib` y dejé en blanco Import-Export Slots, ya que PBS los lee del changer.

{% include image.html url="/assets/img/2026-11-13-pbs-usb-p01-add-changer.jpg" description="PBS: agregar el changer" width=1512 height=806 %}

**Drives → Add**: nombre `usbdrive`, changer `usblib`, número de drive 0. La lista de rutas muestra todos los drives de mhVTL, incluidos los de muestra, así que elige el que tiene serial `0MHV002001`:

{% include image.html url="/assets/img/2026-11-13-pbs-usb-p02-add-drive.jpg" description="PBS: agregar el drive, elegido por serial" width=1512 height=806 %}

## Clave de cifrado y media pool {#encryption-key-and-media-pool}

**Encryption Keys → Add**: una pista y una contraseña. PBS luego ofrece una clave en papel. Imprímela y guárdala lejos de este servidor: sin la clave, los discos son puro ruido.

{% include image.html url="/assets/img/2026-11-13-pbs-usb-p03-add-key.jpg" description="PBS: agregar una clave de cifrado de cintas" width=1512 height=806 %}

**Media Pools → Add**:

- **Name:** offsite
- **Allocation:** always. Cada ejecución inicia un nuevo media set. Mientras una ejecución quepa en un disco, cada disco es una copia autónoma que puede salir del edificio.
- **Retention:** 20 días. Tiene que ser menor que el ciclo de rotación: tres discos rotados semanalmente vuelven a los 21 días.
- **Encryption key:** la que acabas de crear.

{% include image.html url="/assets/img/2026-11-13-pbs-usb-p04-add-pool.jpg" description="PBS: media pool offsite" width=1512 height=806 %}

## Etiquetar el disco {#label-the-disk}

Abre el changer (**usblib** en el árbol de la izquierda). El disco está en el slot I/E 5, "Not Labeled". Los slots de correo se numeran a continuación de los cuatro slots de almacenamiento. PBS no etiqueta medios que están en un slot de correo, así que haz clic en **Import** y muévelo al slot 1, luego **Barcode Label** con el pool `offsite`.

{% include image.html url="/assets/img/2026-11-13-pbs-usb-p05-changer-ie.jpg" description="Vista del changer en PBS: el disco nuevo en el slot I/E 5" width=1512 height=806 %}

## Respaldar {#back-up}

**Content → New Backup**: datastore `store1`, pool `offsite`, drive `usbdrive`, y marca **Export Media-Set**. Eso devuelve el cartucho al slot de correo cuando termina el trabajo, listo para desconectar.

{% include image.html url="/assets/img/2026-11-13-pbs-usb-p06-new-backup.jpg" description="PBS: nuevo respaldo en cinta con Export Media-Set" width=1512 height=806 %}

{% include image.html url="/assets/img/2026-11-13-pbs-usb-p07-backup-log.jpg" description="Log de la tarea: 2148 MB escritos, medio exportado al slot I/E 5" width=1512 height=806 %}

Para la rutina semanal, agrega un trabajo en **Backup Jobs → Add**: mismo datastore, pool y drive, horario `sat 02:00`, con Export Media-Set marcado.

{% include image.html url="/assets/img/2026-11-13-pbs-usb-p11-backup-job.jpg" description="PBS: trabajo semanal de respaldo en cinta" width=1512 height=806 %}

## Sacar el disco {#pull-the-disk}

Cuando el log de la tarea diga que el medio fue exportado, desconecta el disco. El bay monitor saca el cartucho de la biblioteca. PBS guarda en caché lo que sabe, así que haz clic en **Reload** en **Inventory**: el disco aparece como offline, con su catálogo.

{% include image.html url="/assets/img/2026-11-13-pbs-usb-p08-inventory-offline.jpg" description="Inventario de PBS: USB001L8 offline, catálogo conservado" width=1512 height=806 %}

La vista del changer también sigue mostrando el cartucho hasta que haces clic en **Reload** ahí.

La semana que viene: conecta el disco que corresponde, hazle **Import** a un slot de almacenamiento y deja correr el trabajo. Un disco vencido se reutiliza automáticamente. Formatear y etiquetar es solo para discos nuevos.

## Restaurar {#restore}

Vuelve a conectar el disco. Cuando esté en el slot de correo, haz **Reload** del changer e **Import** a un slot. Luego, en **Content**, haz clic en el ícono de restaurar junto al media set, elige los snapshots y escoge un drive y un datastore de destino:

{% include image.html url="/assets/img/2026-11-13-pbs-usb-p09-restore-target.jpg" description="Asistente de restauración de PBS: drive y datastore de destino" width=1512 height=806 %}

{% include image.html url="/assets/img/2026-11-13-pbs-usb-p10-restore-log.jpg" description="Log de restauración: el media set estaba cifrado con la clave del pool" width=1512 height=806 %}

El log muestra la huella de la clave con la que se cifró el media set, y la restauración devolvió 2,148 GB al datastore. El archivo aleatorio de 2 GiB de ese snapshot volvió con el mismo SHA-256 que el original.

La restauración deja el disco en el drive. Antes de desconectarlo, devuélvelo al slot de correo desde la vista del changer. Haz clic en **Unload** en las acciones del drive, lo que devuelve el cartucho al slot 1. Luego haz clic en **Transfer** en el slot 1 y elige el slot I/E 5. (El ícono junto a Transfer es **Format**. No los confundas.)

{% include image.html url="/assets/img/2026-11-13-pbs-usb-p12-transfer-to-ie.jpg" description="Vista del changer: USB001L8 de vuelta en el slot I/E 5, listo para desconectar" width=1456 height=818 %}

Restaurar en un PBS reconstruido requiere unos pasos más, empezando por recuperar la clave desde la copia en papel. La [parte 2](/es/datacenter/2026/11/13/pbs-usb-tapes-2-cli.html#restore) tiene los comandos, todos ejecutados en un entorno de prueba.

## Aristas sin pulir {#rough-edges}

mhVTL Control 0.6.0 es joven, y esta corrida mostró algunas cosas que voy a arreglar:

- Las bibliotecas de ejemplo que contienen cartuchos no se pueden eliminar desde el panel: el borrado falla su propia verificación. No estorban, salvo por una lista de drives más larga en PBS.
- El panel de medios muestra un error "Maximum call stack size exceeded".
- Raw Disk Dock ofrece **Format…** para la unidad de CD-ROM, y nombra los discos por `sdX` en lugar de por su bay.

Ninguna interfirió con el procedimiento. Las advertencias de la [parte 2](/es/datacenter/2026/11/13/pbs-usb-tapes-2-cli.html#caveats) también valen aquí: espera al slot de correo antes de sacar un disco, usa un dock que respete los flush de caché y prueba una restauración antes de depender de esto.

---

{% include series-nav.html %}
