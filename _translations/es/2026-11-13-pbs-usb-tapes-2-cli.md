---
title: "Discos USB como cintas para Proxmox Backup Server (2/3): por la línea de comandos"
description: "Paso a paso, desde el shell. Instala mhVTL, define una biblioteca con un dock USB como mail slot, formatea discos como cartuchos de cinta y ejecuta jobs de cinta cifrados de PBS y restauraciones contra ellos."
date: 2026-11-13 10:01:00 -0300
permalink: /es/datacenter/2026/11/13/pbs-usb-tapes-2-cli.html
lang: es
categories:
  - storage-backup
tags:
  - proxmox
  - pbs
  - tape
  - mhvtl
series: pbs-usb-tapes
series_part: 2
series_title: Por la línea de comandos
---

En la [parte 1](/es/datacenter/2026/11/13/pbs-usb-tapes-1-why.html) expliqué por qué te podría interesar tener jobs de cinta de PBS sobre simples discos USB. Esta parte lo arma desde el shell: una biblioteca virtual, una unidad LTO-8, un dock USB que hace de mail slot de la biblioteca y un media pool cifrado que rota discos.

Todos los comandos y salidas de abajo vienen de una corrida en un entorno de pruebas nuevo. Si prefieres hacer clic, la [parte 3](/es/datacenter/2026/11/13/pbs-usb-tapes-3-gui.html) hace lo mismo desde las interfaces web.

<!--more-->

{% include series-nav.html %}

## Punto de partida {#starting-point}

- Proxmox Backup Server 4.2 con un datastore que contenga algunos backups. El mío se llama `store1`.
- Un dock USB o adaptador USB-SATA, más los discos que quieras rotar. Un disco es un cartucho.
- mhVTL `1.8.0+git20261101.7e3a101` de mi [proyecto en openSUSE Build Service](https://build.opensuse.org/project/show/home:ciriarte:mhvtl). Todo lo que se usa aquí está en el master de mhVTL pero todavía no en una versión etiquetada, de ahí el snapshot.

Mi entorno de pruebas fue una VM con Debian 13 y PBS instalado encima, y el "dock USB" un puerto USB de un controlador xHCI virtual en el que conecté en caliente discos de 16 GB. El kernel ve eventos reales de hot-plug USB, así que mhVTL no nota la diferencia. Los números de throughput son de esa VM, no son un benchmark.

Los pasos asumen un host PBS que todavía no tiene mhVTL: reemplazan la configuración de ejemplo que instala el paquete. Si ya tienes bibliotecas mhVTL en ese host, agrega la biblioteca y la unidad de abajo a tu propio `device.conf`.

Ejecuta todo como root.

## Instalar mhVTL {#install-mhvtl}

Agrega el repositorio e instala mhVTL. El módulo del kernel se compila con DKMS, así que nombra explícitamente el paquete de headers:

{% highlight shell %}
REPO=https://download.opensuse.org/repositories/home:/ciriarte:/mhvtl/Debian_13
install -d /etc/apt/keyrings
curl -fsSL -o /etc/apt/keyrings/mhvtl.asc $REPO/Release.key
echo "deb [signed-by=/etc/apt/keyrings/mhvtl.asc] $REPO/ /" \
    > /etc/apt/sources.list.d/mhvtl.list
apt-get update
# PBS on top of Debian:
apt-get install linux-headers-amd64 mhvtl
# PBS from the ISO (Proxmox kernel), instead:
#apt-get install proxmox-default-headers mhvtl
{% endhighlight %}

**Nota:** Los headers tienen que coincidir con el kernel en ejecución. Si acabas de actualizar el kernel, reinicia primero, o DKMS compila el módulo solo para el kernel que todavía no estás usando. Nombra también el metapaquete de headers: sin eso, apt instaló los headers del kernel de Proxmox en mi equipo con kernel de Debian para satisfacer `mhvtl-dkms`.

La instalación todavía no inicia mhVTL, lo que deja tiempo para un paso más. El driver `ch` de Linux pierde una referencia a cada unidad cada vez que aparece un changer, así que una unidad que mhVTL elimina no puede volver hasta reiniciar ([corregido en 7.3-rc7](https://git.kernel.org/torvalds/c/27c0f718d3b3), no está en los kernels actuales de PBS). PBS habla con los changers a través de `/dev/sg*` y no necesita `ch`, así que mantenlo fuera:

{% highlight shell %}
echo "blacklist ch" > /etc/modprobe.d/mhvtl-no-ch.conf
# if this fails, ch is in use: reboot before going on
modprobe -r ch
{% endhighlight %}

## Definir la biblioteca {#define-the-library}

El paquete trae dos bibliotecas STK de ejemplo, y PBS no ve ninguna de las dos. PBS solo lista un changer cuando udev le da un `ID_SCSI_SERIAL`, que sale de la página VPD 0x83 del INQUIRY. El STK L700 y el L80 que mhVTL emula fielmente no la tienen, así que uso una personalidad IBM TS3500 (`03584L22`), que sí.

Guarda una copia de los ejemplos y luego reemplaza `/etc/mhvtl/device.conf` por uno con una biblioteca y una unidad:

{% highlight shell %}
cp -a /etc/mhvtl /root/mhvtl.orig
{% endhighlight %}

**`/etc/mhvtl/device.conf`**

{% highlight text %}
VERSION: 5

Library: 10 CHANNEL: 00 TARGET: 00 LUN: 00
 Vendor identification: IBM
 Product identification: 03584L22
 Unit serial number: USBLIB01
 NAA: 10:22:33:44:ab:00:00:00
 Home directory: /var/lib/mhvtl
 PERSIST: False
 Backoff: 400

Drive: 11 CHANNEL: 00 TARGET: 01 LUN: 00
 Library ID: 10 Slot: 01
 Vendor identification: IBM
 Product identification: ULT3580-TD8
 Product revision level: HB81
 Unit serial number: USBDRV01
 NAA: 10:22:33:44:ab:00:01:00
 Compression: factor 1 enabled 1
 Compression type: lz4
 Backoff: 400
{% endhighlight %}

No hay una línea `Encryption:` porque AES-256-GCM es el valor por defecto para las unidades que lo soportan (ver `man device.conf`). Los chunks de PBS ya vienen comprimidos, así que LZ4 es simplemente el códec más barato que se puede tener habilitado.

Luego, el contenido de la biblioteca: cuatro slots de almacenamiento y dos mail slots, todos vacíos. Los discos traen sus propios cartuchos.

**`/etc/mhvtl/library_contents.10`**

{% highlight text %}
VERSION: 2

Drive 1:

Picker 1:

MAP 1:
MAP 2:

Slot 1:
Slot 2:
Slot 3:
Slot 4:
{% endhighlight %}

Elimina la segunda biblioteca de ejemplo e inicia mhVTL. Un generador de systemd construye las unidades `vtllibrary@`/`vtltape@` a partir de `device.conf`, de ahí el reload:

{% highlight shell %}
rm -f /etc/mhvtl/library_contents.30
systemctl daemon-reload
systemctl restart mhvtl.target
sleep 5; lsscsi -g
{% endhighlight %}

{% highlight text %}
[7:0:0:0]    mediumx IBM      03584L22         0108  /dev/sch0  /dev/sg2
[7:0:1:0]    tape    IBM      ULT3580-TD8      HB81  /dev/st0   /dev/sg3
{% endhighlight %}

Los dispositivos tardan unos segundos en aparecer después del reinicio. (Mi corrida muestra `/dev/sch0` porque `ch` todavía no estaba en la lista negra. Con la lista negra aplicada, esa columna muestra `-`.)

## Asociar el dock a un mail slot {#bind-the-dock-to-a-mail-slot}

`mhvtl-bay-monitor` asocia la ubicación física de un disco con los mail slots de una biblioteca. La ubicación es el nombre estable en `/dev/disk/by-path` del puerto USB, nunca `/dev/sdX`. Conecta cualquier disco al dock y búscalo:

{% highlight shell %}
ls -l /dev/disk/by-path/ | grep usb
{% endhighlight %}

{% highlight text %}
pci-0000:00:01.0-usb-0:1:1.0-scsi-0:0:0:0 -> ../../sdb
pci-0000:00:01.0-usbv3-0:1:1.0-scsi-0:0:0:0 -> ../../sdb
{% endhighlight %}

Usa el nombre `usb-` simple. El `usbv3-` lleva la versión de USB que negoció el disco, así que un disco que caiga a USB 2 aparecería con otro nombre. Todos los discos conectados a este puerto caen en la misma bahía, que es justo lo que necesita una rotación.

Asócialo a la biblioteca 10 e inicia el monitor. La segunda columna es el mail slot previsto; por ahora el cartucho cae en el primero libre, que con un solo dock es siempre el mismo:

{% highlight shell %}
BAY=/dev/disk/by-path/pci-0000:00:01.0-usb-0:1:1.0-scsi-0:0:0:0
echo "10  1  $BAY" > /etc/mhvtl/mhvtl_raw_bays.conf
systemctl enable --now mhvtl-bay-monitor
journalctl -u mhvtl-bay-monitor -o cat | grep -E 'handle_add|monitoring'
{% endhighlight %}

Las líneas de log de aquí en adelante abrevian el nombre by-path a `…usb-0:1:1.0-scsi-0:0:0:0`:

{% highlight text %}
mhvtl-bay-monitor: handle_add(): bay …usb-0:1:1.0-scsi-0:0:0:0 not placed: no readable MVTL cartridge in bay
mhvtl-bay-monitor: main(): monitoring 1 bay(s) for raw-disk hot-plug events
{% endhighlight %}

El disco que está en el dock está en blanco, así que todavía no se coloca nada. Es lo esperado.

## Configurar PBS {#configure-pbs}

PBS ahora encuentra el changer y la unidad:

{% highlight shell %}
proxmox-tape changer scan
{% endhighlight %}

{% highlight text %}
┌───────────────────────────────┬────────┬──────────┬──────────┐
│ path                          │ vendor │ model    │ serial   │
╞═══════════════════════════════╪════════╪══════════╪══════════╡
│ /dev/tape/by-id/scsi-USBLIB01 │ IBM    │ 03584L22 │ USBLIB01 │
└───────────────────────────────┴────────┴──────────┴──────────┘
{% endhighlight %}

{% highlight shell %}
proxmox-tape drive scan
{% endhighlight %}

{% highlight text %}
┌────────────────────────────────────┬────────┬─────────────┬────────────┐
│ path                               │ vendor │ model       │ serial     │
╞════════════════════════════════════╪════════╪═════════════╪════════════╡
│ /dev/tape/by-id/scsi-00USBDRV01-sg │ IBM    │ ULT3580-TD8 │ 00USBDRV01 │
└────────────────────────────────────┴────────┴─────────────┴────────────┘
{% endhighlight %}

Créalos:

{% highlight shell %}
proxmox-tape changer create usblib --path /dev/tape/by-id/scsi-USBLIB01
proxmox-tape drive create usbdrive --path /dev/tape/by-id/scsi-00USBDRV01-sg \
    --changer usblib --changer-drivenum 0
{% endhighlight %}

A continuación, una clave de cifrado y un media pool que la use. `key create` pide una contraseña. Imprime la clave en papel y guárdala lejos de este servidor: sin la clave, nadie puede leer los discos, tú incluido.

{% highlight shell %}
proxmox-tape key create --hint offsite-2026
(umask 077; proxmox-tape key paperkey <fingerprint> --output-format text \
    > /root/offsite-paperkey.txt)
proxmox-tape pool create offsite --allocation always --retention "20 days" \
    --encrypt <fingerprint>
{% endhighlight %}

`--allocation always` inicia un nuevo media set en cada ejecución. Mientras una ejecución quepa en un disco, cada disco es una copia autocontenida que puede salir del edificio. Si no cabe, el media set abarca varios discos, y viajan (y se restauran) juntos.

La retención tiene que ser menor que el ciclo de rotación, o el disco que regresa sigue protegido y PBS pide uno nuevo. Con tres discos rotados semanalmente, un disco vuelve después de 21 días, así que 20 días funciona.

En el changer, los mail slots se numeran después de los slots de almacenamiento. Con cuatro slots, el dock es el elemento 5:

{% highlight shell %}
proxmox-tape changer status usblib
{% endhighlight %}

{% highlight text %}
│ drive         │        0 │            │             │
│ import-export │        5 │            │             │
│ import-export │        6 │            │             │
│ slot          │        1 │            │             │
...
{% endhighlight %}

## Inicializar un disco {#initialize-a-disk}

Esto se hace una vez por disco y **borra todo lo que tenga**. Formatea el disco que está en el dock como cartucho. El sufijo de código de barras `L8` lo hace medio LTO-8, igual que la unidad, y la capacidad es la que tenga el disco:

{% highlight shell %}
mhvtl-raw-format $BAY --barcode USB001L8
{% endhighlight %}

{% highlight text %}
Formatted …usb-0:1:1.0-scsi-0:0:0:0 as raw cartridge 'USB001L8' (partitions: 100, min record 65536 bytes)
{% endhighlight %}

El monitor lo detecta solo y deja el cartucho en el mail slot:

{% highlight shell %}
journalctl -u mhvtl-bay-monitor -o cat | tail -1
{% endhighlight %}

{% highlight text %}
mhvtl-bay-monitor: handle_add(): placed USB001L8 (library 10 MAP, bay …usb-0:1:1.0-scsi-0:0:0:0)
{% endhighlight %}

PBS cachea el estado del changer, así que pide una lectura nueva:

{% highlight shell %}
proxmox-tape changer status usblib --cache false
{% endhighlight %}

{% highlight text %}
Unit Attention, Additional sense: Import or export element accessed
│ import-export │        5 │ USB001L8   │             │
{% endhighlight %}

El "Unit Attention" es la biblioteca avisándole a PBS que alguien tocó el mail slot. Así se comporta también una biblioteca real.

PBS no etiqueta medios que están en un mail slot (`changer device does not list any media labels`), así que primero muévelo a un slot de almacenamiento. Luego `barcode-label` etiqueta con su código de barras cada cartucho sin etiquetar de la biblioteca:

{% highlight shell %}
proxmox-tape changer transfer usblib --from 5 --to 1
proxmox-tape barcode-label --drive usbdrive --pool offsite
{% endhighlight %}

{% highlight text %}
checking/loading media 'USB001L8'
Label media 'USB001L8' for pool 'offsite'
TASK OK
{% endhighlight %}

## Ejecutar un backup {#run-a-backup}

`--export-media-set` devuelve el cartucho al mail slot cuando termina el job, así el disco está listo para sacarse apenas termina la tarea:

{% highlight shell %}
proxmox-tape backup store1 offsite --drive usbdrive --export-media-set true
{% endhighlight %}

{% highlight text %}
starting new media set - reason: policy is AlwaysCreate
...
allocated new writable media 'USB001L8'
trying to load media 'USB001L8' into drive 'usbdrive'
found media label USB001L8 (7288ea87-d337-408b-97cf-e3d3f1f2ba9c)
writing new media set label
wrote 547 chunks (2148.01 MB at 84.90 MB/s)
...
exported media 'USB001L8' to import/export slot 5
TASK OK
{% endhighlight %}

Para la rutina semanal, conviértelo en un job:

{% highlight shell %}
proxmox-tape backup-job create weekly-usb --store store1 --pool offsite \
    --drive usbdrive --schedule "sat 02:00" --export-media-set true
{% endhighlight %}

`proxmox-tape backup-job run weekly-usb` lo ejecuta a demanda.

¿Está realmente cifrado el disco? Busqué en los 16 GB del dispositivo crudo cuatro muestras de 32 bytes de un archivo aleatorio de ese backup. Cada muestra apareció una vez en el datastore de PBS y en ningún lugar del disco.

## Sacar el disco {#pull-the-disk}

Verifica que el cartucho esté en el mail slot y luego desconecta el disco:

{% highlight shell %}
proxmox-tape changer status usblib --cache false | grep import-export
{% endhighlight %}

{% highlight text %}
│ import-export │        5 │ USB001L8   │             │
{% endhighlight %}

El monitor saca el cartucho de la biblioteca:

{% highlight shell %}
journalctl -u mhvtl-bay-monitor -o cat | tail -1
{% endhighlight %}

{% highlight text %}
mhvtl-bay-monitor: handle_remove(): removed USB001L8 (library 10 MAP, bay …usb-0:1:1.0-scsi-0:0:0:0)
{% endhighlight %}

PBS mantiene el disco en su inventario como medio offline, con su catálogo:

{% highlight shell %}
proxmox-tape media list
{% endhighlight %}

{% highlight text %}
│ label-text │ pool    │ media-set-name           │ seq-nr │ status │ location │ catalog │
│ USB001L8   │ offsite │ Fri Nov 13 13:09:32 2026 │      0 │ full   │ offline  │      ok │
{% endhighlight %}

Si un backup se ejecutó sin `--export-media-set`, haz tú mismo la exportación antes de sacar el disco:

{% highlight shell %}
proxmox-tape unload --drive usbdrive
proxmox-tape export-media --drive usbdrive USB001L8
{% endhighlight %}

## La rutina semanal {#the-weekly-routine}

Una vez inicializados los discos, una rotación es:

1. Conecta el disco que corresponde. Aparece en el mail slot 5.
2. `proxmox-tape changer transfer usblib --from 5 --to 1`
3. Deja que corra el job. Exporta el disco de vuelta al slot 5.
4. Desconéctalo y llévalo fuera del sitio.

Un disco vencido es reutilizado automáticamente por el pool. `mhvtl-raw-format` y `barcode-label` solo hacen falta para discos nuevos. En el entorno de pruebas, un segundo disco (`USB002L8`) pasó por los mismos pasos, y el job escribió en él por su cuenta.

## Restauración {#restore}

Vuelve a conectar el disco, muévelo a un slot de almacenamiento y restaura su media set en un datastore. `proxmox-tape media list` muestra el UUID del media set:

{% highlight shell %}
proxmox-tape changer transfer usblib --from 5 --to 1
proxmox-tape media list
MEDIA_SET=68f8efda-3abe-41be-8bb4-8387fa27ebee   # yours, from the list
proxmox-backup-manager datastore create restore1 /srv/restore1
proxmox-tape restore $MEDIA_SET restore1 --drive usbdrive
{% endhighlight %}

{% highlight text %}
Encryption key fingerprint: 05:7c:64:f4:19:93:0d:c8:...
...
restored 2.148 GB (134.69 MB/s)
restore snapshot host/lab-host/2026-11-13T13:01:34Z
TASK OK
{% endhighlight %}

La clave está en el almacén de claves de PBS, así que la restauración no pidió nada. El archivo aleatorio de 2 GiB de ese snapshot volvió con el mismo SHA-256 que el original.

La restauración deja el disco en la unidad. Devuélvelo al mail slot antes de desconectarlo:

{% highlight shell %}
proxmox-tape unload --drive usbdrive
proxmox-tape export-media --drive usbdrive USB001L8
{% endhighlight %}

En un PBS reconstruido, el almacén de claves y el catálogo de medios ya no existen. Configura de nuevo mhVTL y el changer y la unidad de PBS como arriba, pero **no formatees ni etiquetes los discos**. Conecta el disco, muévelo a un slot, luego recupera la clave desde la copia en papel y deja que PBS lea el disco:

{% highlight shell %}
# asks for the key password:
proxmox-tape key restore --key-file /root/offsite-paperkey.txt
proxmox-tape inventory --drive usbdrive --read-all-labels true
proxmox-tape load-media USB001L8 --drive usbdrive
proxmox-tape catalog --drive usbdrive
{% endhighlight %}

{% highlight text %}
searching for catalog at EOT (moving to EOT)
found catalog at pos 4
successfully restored catalog
TASK OK
{% endhighlight %}

Luego restaura el media set como arriba. Lo probé borrando la clave, el pool, el inventario y los catálogos del PBS de pruebas: la restauración a un datastore nuevo funcionó y el checksum coincidió.

## Salvedades {#caveats}

- **No saques un disco cargado.** Lo intenté: mientras el disco estaba afuera, la unidad reportó "Medium format corrupted". Después de volver a conectarlo, `proxmox-tape unload` seguido de `proxmox-tape load-media USB001L8 --drive usbdrive` lo recuperó, y un reescaneo completo del catálogo leyó bien los datos. Aun así, espera al mail slot.
- **Puentes USB y flushes.** mhVTL pide un flush en cada filemark y en cada unload, pero algunos puentes USB-SATA baratos ignoran los flushes de caché. Compra un dock UAS decente.
- **Más docks.** Un segundo dock es otra línea en `mhvtl_raw_bays.conf` (reinicia `mhvtl-bay-monitor` después). Cada disco cae en el primer mail slot libre, no necesariamente el de su línea, así que revisa `changer status --cache false` para ver el código de barras antes de mover o sacar cualquier cosa. Sacar un disco solo retira su propio cartucho.
- **El cifrado necesita este snapshot o uno más nuevo.** En builds de mhVTL anteriores a [#328](https://github.com/markh794/mhvtl/pull/328), el cifrado de la unidad es simulado y la clave se escribe junto a los datos. Revisa `man device.conf` para ver la opción `Encryption:`. Si no está, usa el [cifrado del lado del cliente de PBS](https://pbs.proxmox.com/docs/backup-client.html#encryption).
- **Código nuevo.** Los cartuchos de disco crudo son jóvenes. Prueba una restauración antes de depender de ellos, como con cualquier backup.

---

{% include series-nav.html %}
