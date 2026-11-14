---
title: "Reducir el mirror ZFS de root de un Proxmox Backup Server"
description: "Un procedimiento de campo para reducir particiones root ZFS en mirror sobredimensionadas en Proxmox Backup Server, reconstruyendo un lado del mirror a la vez y manteniendo una alternativa booteable hasta el final. Probado con BIOS legacy, UEFI con systemd-boot y UEFI con Secure Boot."
lang: es
date: 2026-11-14 13:00:00 -0300
permalink: /es/2026/11/14/shrinking-pbs-zfs-root-mirror.html
categories:
  - storage-backup
tags:
  - pbs
  - zfs
---

Después de instalar Proxmox Backup Server en un par de SSD de 200GB con un mirror ZFS de root (`rpool`), me di cuenta de que el sistema de archivos raíz usaba menos de 3GB. Quería recuperar el espacio restante para otro uso, pero ZFS no permite reducir vdevs de primer nivel ni pools en el lugar. Truncar directamente las particiones GPT subyacentes es la forma de corromper un pool.

El enfoque que usé es una migración escalonada del mirror: separar un lado del mirror, crear un pool más chico de 50GB en ese disco, replicar el sistema de archivos raíz, arrancar desde el nuevo pool y, por último, reparticionar y volver a adjuntar el segundo disco para restaurar el mirror. El disco viejo queda intacto, y booteable, hasta que el nuevo demuestra que puede arrancar por sí solo.

Todo se hace sobre el sistema en vivo; nunca tuve que arrancar con medios de rescate. De todos modos, tenlos a mano.

<!--more-->

## ¿Aplica a tu caso? {#does-this-apply-to-you}

Esto se escribió para, y se ejecutó en, una configuración bastante específica. Verifica que la tuya coincida antes de seguir:

- Una de las tres configuraciones de arranque que administra `proxmox-boot-tool`. Mi servidor arranca en BIOS legacy con GRUB; el procedimiento también funciona en UEFI, con algunas diferencias que se cubren más abajo.
- Sin cifrado nativo de ZFS en el pool raíz.
- La distribución por defecto del instalador: root en `rpool/ROOT/pbs-1`. Si `findmnt -n -o SOURCE /` muestra otro dataset, sustitúyelo en todo lo que sigue.
- SSH como root más acceso a consola fuera de banda (iLO, IPMI, serie, carrito de emergencia), porque puede que necesites el menú de arranque del firmware.

Para ver qué configuración de arranque tienes, mira la primera línea de `proxmox-boot-tool status` y con qué está "configured with" cada partición de arranque, y en UEFI revisa Secure Boot:

{% highlight shell %}
proxmox-boot-tool status
mokutil --sb-state
{% endhighlight %}

| Configuración de arranque | `proxmox-boot-tool status` | Gestor de arranque | `INIT_MODE` más abajo |
|---|---|---|---|
| BIOS legacy | arrancado con `legacy`, particiones `grub` | GRUB | `grub` |
| UEFI | arrancado con `uefi`, particiones `uefi` | systemd-boot | vacío |
| UEFI con Secure Boot | arrancado con `uefi`, particiones `grub` | GRUB, cargado por el shim firmado | `grub` |

La parte ZFS del procedimiento es la misma para las tres. Lo que cambia en UEFI es cómo eliges qué disco arranca, y que el firmware mantiene su propia lista de entradas de arranque, cada una apuntando a una partición específica, que necesita algo de orden después de reparticionar los discos. Esos pasos están marcados con **UEFI**.

Después de la primera ejecución en hardware real, repetí todo el procedimiento, tal como está escrito aquí, en VMs nuevas de Proxmox Backup Server 4.2 con root ZFS RAID1: una con SeaBIOS, una con UEFI y systemd-boot y una con UEFI y Secure Boot habilitado. Cada ejecución cubrió la sincronización base e incremental, el primer arranque desde el disco nuevo, un arranque de rollback desde el viejo, la reconstrucción del segundo disco y un arranque desde cada disco con el otro retirado; Secure Boot se mantuvo habilitado todo el tiempo. Dos de los pasos que siguen, vaciar temprano la lista de particiones de arranque y las llamadas a `udevadm settle`, están ahí porque la primera repetición falló sin ellos.

## Punto de partida {#starting-point}

El host era un Proxmox Backup Server con un pool raíz ZFS en mirror:

{% highlight text %}
rpool
  mirror-0
    /dev/sda3
    /dev/sdb3
{% endhighlight %}

Los dos discos de arranque se veían más o menos así:

{% highlight text %}
/dev/sda1   BIOS boot partition
/dev/sda2   EFI System Partition, used by proxmox-boot-tool with GRUB
/dev/sda3   ZFS member, around 185G

/dev/sdb1   BIOS boot partition
/dev/sdb2   EFI System Partition, used by proxmox-boot-tool with GRUB
/dev/sdb3   ZFS member, around 185G
{% endhighlight %}

El sistema arrancaba en modo BIOS legacy, pero igual usaba el flujo de Proxmox boot-tool para administrar las particiones de arranque:

{% highlight shell %}
proxmox-boot-tool status
{% endhighlight %}

El objetivo era dejar ambas particiones root ZFS en 50GB:

{% highlight text %}
/dev/sda3   50G
/dev/sdb3   50G
{% endhighlight %}

Este procedimiento deja intencionalmente el pool de reemplazo con el nombre `newrpool`. Renombrar un pool raíz de vuelta a `rpool` implica exportarlo y reimportarlo desde un entorno fuera de línea y refrescar la configuración de arranque; eso es otro trabajo, y no vale la pena mezclarlo con la reducción. Dejé el nombre como está.

## Advertencias importantes {#important-warnings}

Esto es destructivo.

Antes de hacer algo así, asegúrate de tener:

- Acceso fuera de banda a la consola y al menú de arranque del firmware.
- Un destino de backup fuera del pool raíz.
- El mapeo de discos verificado, por número de serie, para ambos discos.
- Un backup verificado, no solo un comando de backup que pareció ejecutarse.
- Suficiente soltura con medios de rescate como para recuperar un sistema Proxmox con root ZFS si el arranque falla.

No instales actualizaciones mientras el procedimiento está en curso: una actualización del kernel ejecuta `proxmox-boot-tool refresh` y toca todas las particiones de arranque registradas.

No pegues los comandos a ciegas. Ajusta los nombres de pools, de datasets y las rutas by-id a tu sistema, y lee la salida de cada paso antes de ejecutar el siguiente.

## Inspeccionar el sistema {#inspect-the-system}

Empieza por recopilar la distribución real.

{% highlight shell %}
hostname
cat /etc/os-release
cat /proc/cmdline
findmnt -n -o SOURCE /

lsblk -o NAME,PATH,SIZE,TYPE,FSTYPE,UUID,MOUNTPOINTS

zpool status -v
zpool list -v
zfs list -r -o name,used,avail,refer,mountpoint,canmount rpool

proxmox-boot-tool status
swapon --show

sgdisk -p /dev/sda
sgdisk -p /dev/sdb
{% endhighlight %}

Confirma que root realmente está en ZFS y que `sda3` y `sdb3` son los miembros del vdev raíz en mirror. Revisa también si hay datasets adicionales en el pool raíz, swap en un zvol o propiedades poco habituales como `canmount`, `mountpoint`, `quota` o `refreservation`; la replicación las va a preservar, pero es mejor encontrar sorpresas aquí que después del reinicio.

Identifica las rutas estables de los discos antes de tocar nada:

{% highlight shell %}
ls -l /dev/disk/by-id/ | grep -E 'sda|sdb'
{% endhighlight %}

Los nombres del kernel como `/dev/sda` pueden intercambiarse entre arranques, y este procedimiento reinicia a mitad de camino. Todos los comandos destructivos que siguen usan rutas `/dev/disk/by-id/`, tanto para ZFS como para `sgdisk`.

## Crear un backup {#create-a-backup}

Usé otro datastore ZFS montado en `/mnt/datastore/backup01` como destino del backup.

{% highlight shell %}
TS=$(date +%Y%m%d-%H%M%S)
BK=/mnt/datastore/backup01/rpool-shrink-$TS
mkdir -p "$BK"
echo "$BK" > /root/.last-rpool-shrink-backup
{% endhighlight %}

Captura el estado actual:

{% highlight shell %}
zpool status -v > "$BK/zpool-status.before.txt"
zpool list -v > "$BK/zpool-list.before.txt"
zfs list -r -o name,used,avail,refer,mountpoint,canmount rpool > "$BK/zfs-list.before.txt"
zfs get -r all rpool > "$BK/zfs-get-all.before.txt"
lsblk -o NAME,PATH,SIZE,TYPE,FSTYPE,UUID,PARTUUID,PARTTYPE,MOUNTPOINTS > "$BK/lsblk.before.txt"

sgdisk --backup="$BK/sda.gpt" /dev/sda
sgdisk --backup="$BK/sdb.gpt" /dev/sdb

proxmox-boot-tool status > "$BK/proxmox-boot-tool-status.before.txt" 2>&1 || true
proxmox-backup-manager versions > "$BK/proxmox-backup-manager-versions.before.txt" 2>&1 || true
{% endhighlight %}

Crea un backup conservador a nivel de sistema de archivos de las rutas importantes del sistema:

{% highlight shell %}
umask 077

tar --xattrs --acls --one-file-system \
  -czf "$BK/etc-root-boot-varlibpbs.tar.gz" \
  /etc /root /boot /var/lib/proxmox-backup \
  2> "$BK/tar-warnings.txt" || true
{% endhighlight %}

Ahora crea el backup por replicación ZFS. La ejecución en seco primero te dice qué tan grande es el stream recursivo, con los snapshots incluidos; tiene que caber holgadamente en el nuevo pool de 50GB, no solo los 3GB del root en vivo:

{% highlight shell %}
SN="pre-shrink-$TS"
zfs snapshot -r "rpool@$SN"
zfs send -nvR "rpool@$SN" | tail -1

zfs send -R "rpool@$SN" > "$BK/rpool-$SN.zfs"
echo "$SN" > "$BK/base-snapshot-name.txt"
sha256sum "$BK"/* > "$BK/SHA256SUMS"
sync
{% endhighlight %}

Verifica los checksums antes de continuar:

{% highlight shell %}
cd "$BK"
sha256sum -c SHA256SUMS
zfs list -t snapshot -r rpool | grep "$SN"
{% endhighlight %}

Si la verificación de checksums falla, detente.

Más adelante, el nuevo pool se carga desde este archivo y no directamente desde `zfs send`. Es deliberado: el receive sirve además como prueba de restauración del stream de backup, antes de cualquier cosa que no se pueda deshacer.

## Separar un lado del mirror {#detach-one-side-of-the-mirror}

La estrategia es mantener la máquina funcionando desde un lado del mirror viejo mientras reconstruimos el otro lado como un pool nuevo y más chico.

En mi caso separé primero el lado de `sdb`.

Define las variables según tu hardware, usando las rutas by-id de disco completo que identificaste antes, y guárdalas junto al backup. El shell las olvida con el reinicio, y la segunda mitad del procedimiento las necesita:

{% highlight shell %}
OLDPOOL=rpool
NEWPOOL=newrpool
BK=$(cat /root/.last-rpool-shrink-backup)

SDA=/dev/disk/by-id/ata-Micron_P400m-MTFDDAK200MAN_MSA173201JY
SDB=/dev/disk/by-id/ata-Micron_P400m-MTFDDAK200MAN_MSA173201MA
SDA3=$SDA-part3
SDB3=$SDB-part3

# grub for legacy BIOS and for UEFI with Secure Boot; empty for UEFI with systemd-boot
INIT_MODE=grub

SN_BASE=$(cat "$BK/base-snapshot-name.txt")
zfs list "$OLDPOOL@$SN_BASE"
ls -l "$BK/rpool-$SN_BASE.zfs"

cat > "$BK/vars.sh" <<EOF
OLDPOOL=$OLDPOOL
NEWPOOL=$NEWPOOL
BK=$BK
SDA=$SDA
SDB=$SDB
SDA3=$SDA3
SDB3=$SDB3
INIT_MODE=$INIT_MODE
SN_BASE=$SN_BASE
EOF
cat "$BK/vars.sh"
{% endhighlight %}

Si falla `zfs list` o `ls`, detente: el snapshot y el archivo de stream tienen que coincidir. Define `INIT_MODE` según la tabla de arriba; es la única opción que depende de cómo arranca la máquina.

Separa `sdb3` del pool raíz viejo y confirma que `rpool` ahora es de un solo disco:

{% highlight shell %}
zpool detach "$OLDPOOL" "${SDB3:?}"
zpool status -P "$OLDPOOL"
{% endhighlight %}

`zpool status` debería listar solo la ruta de `sda3`. En este punto el `rpool` viejo ya no está en mirror. No te quedes sin energía a menos que estés seguro de que tu backup y el acceso a consola están bien.

## Reparticionar sdb {#repartition-sdb}

Borra y vuelve a crear la tabla de particiones en el disco `sdb`, con la partición 3 de 50GB:

{% highlight shell %}
sgdisk --zap-all "${SDB:?}"
sgdisk -a1 -n1:34:2047 -t1:EF02 "$SDB"
sgdisk -n2:2048:+1G -t2:EF00 "$SDB"
sgdisk -n3:0:+50G -t3:BF01 "$SDB"
partx -u "$SDB"
udevadm settle

sgdisk -v "$SDB"
sgdisk -p "$SDB"
lsblk -o NAME,SIZE,PARTTYPENAME "$SDB"
{% endhighlight %}

La primera partición es la diminuta partición de arranque BIOS. La segunda es la EFI System Partition que usa `proxmox-boot-tool`. La tercera es la nueva partición ZFS de 50GB. `sgdisk -v` no debería reportar problemas y `lsblk` debería mostrar las tres particiones con los tamaños esperados; si no, detente aquí, mientras el pool viejo sigue intacto en `sda`.

## Crear el nuevo pool más chico {#create-the-new-smaller-pool}

Crea el nuevo pool en la partición `sdb3`, más chica:

{% highlight shell %}
zpool create -f \
  -o ashift=12 \
  -O acltype=posixacl \
  -O canmount=off \
  -O compression=on \
  -O normalization=formD \
  -O relatime=on \
  -O xattr=sa \
  -R /mnt/newrpool \
  "$NEWPOOL" "$SDB3"
{% endhighlight %}

`-R` define una raíz alternativa, para que nada del nuevo pool se monte encima del sistema en ejecución. También mantiene el nuevo pool fuera del `/etc/zfs/zpool.cache` del sistema en vivo; el nuevo root recibe su propio archivo de caché más abajo.

Recibe el snapshot base en el nuevo pool. `-u` mantiene los datasets recibidos sin montar por ahora:

{% highlight shell %}
zfs receive -u -F -d "$NEWPOOL" < "$BK/rpool-$SN_BASE.zfs"
zfs list -r "$NEWPOOL"
zfs list "$NEWPOOL/ROOT/pbs-1"
{% endhighlight %}

## Sincronización incremental final {#final-incremental-sync}

Antes de la sincronización final, asegúrate de que PBS no esté en medio de algo y luego detén los servicios que escriben en el pool raíz:

{% highlight shell %}
proxmox-backup-manager task list

systemctl stop proxmox-backup-proxy proxmox-backup
systemctl is-active proxmox-backup-proxy proxmox-backup
sync
{% endhighlight %}

Espera primero a que terminen las tareas de backup, sincronización, verificación o garbage collection en curso. Ambos servicios deben reportar `inactive`; si alguno sigue corriendo, no tomes el snapshot final.

Crea y envía el snapshot incremental final:

{% highlight shell %}
FINAL_SN="shrink-final-$(date +%Y%m%d-%H%M%S)"

zfs snapshot -r "$OLDPOOL@$FINAL_SN"
zfs send -R -I "$OLDPOOL@$SN_BASE" "$OLDPOOL@$FINAL_SN" | zfs receive -u -F -d "$NEWPOOL"

echo "$FINAL_SN" > "$BK/final-snapshot-name.txt"
zfs list -r "$NEWPOOL" > "$BK/newrpool-after-final-recv.txt"
{% endhighlight %}

Define el dataset de arranque y los puntos de montaje, y luego monta explícitamente el nuevo root bajo el altroot:

{% highlight shell %}
zpool set bootfs="$NEWPOOL/ROOT/pbs-1" "$NEWPOOL"
zfs set mountpoint=/ "$NEWPOOL/ROOT/pbs-1"
zfs set mountpoint="/$NEWPOOL" "$NEWPOOL"
zfs set mountpoint="/$NEWPOOL/ROOT" "$NEWPOOL/ROOT"

findmnt /mnt/newrpool >/dev/null || zfs mount "$NEWPOOL/ROOT/pbs-1"
findmnt -n -o SOURCE /mnt/newrpool
{% endhighlight %}

El último comando debe imprimir `newrpool/ROOT/pbs-1`. Un simple `test -d /mnt/newrpool/etc` no alcanza: si el dataset no está montado, los pasos siguientes escribirían en un directorio vacío del root viejo.

## Preparar el nuevo root para arrancar {#prepare-the-new-root-to-boot}

Apunta la línea de comandos del kernel del nuevo root a `newrpool`. Solo cambia el valor de `root=ZFS=`; cualquier otra cosa en la línea de comandos del kernel, como una consola serie, se queda. GRUB lee `/etc/default/grub.d/zfs.cfg`; systemd-boot lee `/etc/kernel/cmdline`. Una instalación nueva tiene ambos sea cual sea el modo de arranque, así que ambos reciben la misma edición y no pueden quedar en desacuerdo:

{% highlight shell %}
grep -n 'root=ZFS=' /mnt/newrpool/etc/default/grub.d/zfs.cfg /mnt/newrpool/etc/default/grub

sed -i "s|root=ZFS=$OLDPOOL/|root=ZFS=$NEWPOOL/|" /mnt/newrpool/etc/default/grub.d/zfs.cfg
[ -f /mnt/newrpool/etc/kernel/cmdline ] && \
  sed -i "s|root=ZFS=$OLDPOOL/|root=ZFS=$NEWPOOL/|" /mnt/newrpool/etc/kernel/cmdline

grep -rn 'root=ZFS=' /mnt/newrpool/etc/default/grub.d/zfs.cfg /mnt/newrpool/etc/kernel/cmdline 2>/dev/null

# Keep the same ZFS host identity after booting the received root.
cp /etc/hostid /mnt/newrpool/etc/hostid
{% endhighlight %}

El primer `grep` muestra dónde vive el argumento de root en tu sistema; en el mío estaba en `/etc/default/grub.d/zfs.cfg`, más `/etc/kernel/cmdline` en las máquinas de prueba UEFI. Después de la edición, cada coincidencia debería decir `root=ZFS=newrpool/ROOT/pbs-1`.

Dale al nuevo root un archivo de caché ZFS que liste solo `newrpool`. La copia que vino en el snapshot es la del sistema viejo, y todavía lista `rpool`; arrancar con esa importaría el pool viejo junto al nuevo:

{% highlight shell %}
rm -f /mnt/newrpool/etc/zfs/zpool.cache
zpool set cachefile=/mnt/newrpool/etc/zfs/zpool.cache "$NEWPOOL"
zdb -C -U /mnt/newrpool/etc/zfs/zpool.cache | grep -E "^[^ ]|name:"
{% endhighlight %}

La salida de `zdb` debería mencionar `newrpool` y nada más.

Monta con bind los sistemas de archivos de runtime para el chroot:

{% highlight shell %}
for d in dev proc sys run; do
  mountpoint -q "/mnt/newrpool/$d" || mount --rbind "/$d" "/mnt/newrpool/$d"
  mount --make-rslave "/mnt/newrpool/$d"
done
{% endhighlight %}

**UEFI:** el bind recursivo de `/sys` también trae `/sys/firmware/efi/efivars` al chroot. `proxmox-boot-tool init` lo necesita ahí para crear la entrada de arranque del firmware para el disco nuevo; `ls /mnt/newrpool/sys/firmware/efi/efivars | head -1` debería listar algo.

Ahora regenera el initramfs y configura la partición de arranque en `sdb2`. La lista de particiones de arranque del nuevo root (`/etc/kernel/proxmox-boot-uuids`) también vino en el snapshot, así que todavía nombra a `sda2`. Vacíala primero, antes de que se ejecute cualquier cosa en el chroot: `update-initramfs` dispara un `proxmox-boot-tool refresh` a través de sus hooks, y con la lista vieja ese refresh reescribe `sda2` para que arranque `newrpool`. Eso es exactamente lo que pasó en mi primera prueba, y elimina silenciosamente tu camino de vuelta.

{% highlight shell %}
ESP_SDB=$(readlink -f "$SDB-part2")
echo "$ESP_SDB"

: > /mnt/newrpool/etc/kernel/proxmox-boot-uuids
chroot /mnt/newrpool update-initramfs -u -k all

chroot /mnt/newrpool proxmox-boot-tool format "$ESP_SDB" --force
udevadm settle
chroot /mnt/newrpool proxmox-boot-tool init "$ESP_SDB" $INIT_MODE

cat /mnt/newrpool/etc/kernel/proxmox-boot-uuids
blkid -s UUID -o value "$ESP_SDB"
{% endhighlight %}

Los dos UUID del final deben ser iguales, y el archivo debe contener solo ese. El `udevadm settle` importa: sin él, `init` puede leer de udev el UUID viejo de la partición antes de que aparezca el recién formateado, registrar ese y después saltearse la partición al copiar los kernels. `init` ya ejecuta un refresh, así que no hace falta un `update-grub` ni un `refresh` aparte. `$INIT_MODE` va deliberadamente sin comillas, para que cuando está vacío `init` no reciba ningún argumento de modo.

**UEFI:** en UEFI, `init` también escribe una entrada de arranque en el firmware, y los dos gestores de arranque lo hacen de forma distinta. Mira el resultado, emparejando entradas con discos por UUID de partición:

{% highlight shell %}
blkid -s PARTUUID -o value "$SDA-part2" "$SDB-part2"
efibootmgr -v | grep -E '^Boot(Order|[0-9A-F]{4}\* (Linux Boot Manager|proxmox))'
{% endhighlight %}

- **systemd-boot** agrega una nueva entrada "Linux Boot Manager" para `sdb2` y la pone primera en el orden de arranque. La entrada de `sda2` se queda, junto a una obsoleta del `sdb2` viejo, que ya no existe; esa se elimina al final.
- **GRUB con Secure Boot** mantiene una sola entrada llamada "proxmox", e `init` la mueve a `sdb2`. `sda` no pierde su camino de vuelta: cada partición de arranque también recibe una copia del cargador en la ruta de medios extraíbles, `\EFI\BOOT\BOOTX64.EFI`, que es lo que el firmware ejecuta cuando eliges el disco en sí desde su menú de arranque. Así fue como mi prueba de rollback arrancó el disco viejo.

Verifica que el initramfs haya tomado el nuevo archivo de caché:

{% highlight shell %}
lsinitramfs /mnt/newrpool/boot/initrd.img-$(uname -r) | grep zpool.cache
{% endhighlight %}

Nada del sistema en ejecución cambia en esta sección. Su propia configuración de GRUB, archivo de caché y lista de particiones de arranque siguen describiendo `rpool`, así que `sda` sigue siendo un camino de vuelta funcional.

Verifica ambas particiones de arranque: `sdb2` debe tener un kernel y una configuración de GRUB apuntando a `newrpool`, y `sda2` todavía debe apuntar a `rpool`:

{% highlight shell %}
mkdir -p /mnt/esp
mount "$ESP_SDB" /mnt/esp
find /mnt/esp -name 'vmlinuz-*' -o -name 'initrd.img-*' | sort
grep -rhoa 'root=ZFS=[^ "]*' /mnt/esp | sort | uniq -c
umount /mnt/esp

mount "$(readlink -f "$SDA-part2")" /mnt/esp
grep -rhoa 'root=ZFS=[^ "]*' /mnt/esp | sort | uniq -c
umount /mnt/esp
{% endhighlight %}

El `grep` busca en toda la partición, así que encuentra la línea de comandos del kernel dondequiera que el gestor de arranque la guarde: `grub/grub.cfg` para GRUB, `loader/entries/` para systemd-boot. En `sdb2` deberías ver los archivos del kernel y del initrd y `root=ZFS=newrpool/ROOT/pbs-1`; en `sda2`, `root=ZFS=rpool/ROOT/pbs-1` y ninguna mención de `newrpool`. GRUB además agrega un `root=ZFS=/ROOT/pbs-1` genérico en ambas; eso es normal, y el valor posterior y específico es el que gana. Si `sda2` menciona `newrpool`, fue redirigida: ejecuta `proxmox-boot-tool refresh` en el sistema en vivo para restaurarla antes de seguir.

Por último, desarma el chroot:

{% highlight shell %}
umount -R /mnt/newrpool
{% endhighlight %}

Aquí no exporto `newrpool`. Los daemons que corren en sus propios espacios de nombres de montaje, como `systemd-udevd`, `systemd-logind` y `chronyd`, guardan copias de los montajes del chroot, y `zpool export` se niega con "pool is busy". No importa: el reinicio cierra el pool, y con el mismo host ID el initramfs lo importa sin quejarse.

## Arrancar desde el disco nuevo {#boot-from-the-new-disk}

`sda` todavía arranca el pool viejo. Esa es la idea: el primer arranque tiene que venir de `sdb` a propósito, o no prueba nada sobre `sdb`.

En BIOS legacy, el firmware sigue arrancando desde `sda` por defecto. Reinicia y, desde la consola, elige el disco `sdb` en el menú de arranque único de la BIOS:

{% highlight shell %}
sync
systemctl reboot
{% endhighlight %}

**UEFI:** para esto no necesitas la consola. Indícale al firmware qué entrada usar solo para el próximo arranque, la que apunta a `sdb2`:

{% highlight shell %}
P=$(blkid -s PARTUUID -o value "$SDB-part2")
efibootmgr -v | grep -i -- "$P"
N=$(efibootmgr -v | grep -i -- "$P" | sed -nE 's/^Boot([0-9A-F]{4}).*/\1/p' | head -1)
efibootmgr --bootnext "${N:?no boot entry for sdb2}"
sync
systemctl reboot
{% endhighlight %}

Con systemd-boot la nueva entrada ya está primera en el orden de arranque, así que `--bootnext` solo lo hace explícito. Después del reinicio, `efibootmgr | grep BootCurrent` te dice qué entrada usó realmente el firmware. No todos los firmwares tratan las entradas de arranque de la misma manera: el firmware de mis VMs de prueba reordenaba el orden de arranque para seguir el orden de discos de la VM, así que un reinicio simple volvía a `sda`. Confía en `BootCurrent` y en `findmnt`, no en el orden que esperabas.

Cuando el host vuelva, verifica que root ahora esté montado desde `newrpool`:

{% highlight shell %}
cat /proc/cmdline
findmnt -n -o SOURCE /
zpool status -v newrpool
zpool list -v newrpool
{% endhighlight %}

Resultado esperado:

{% highlight text %}
root=ZFS=newrpool/ROOT/pbs-1
newrpool/ROOT/pbs-1
newrpool  49.5G  ONLINE
{% endhighlight %}

Si en cambio terminaste en `rpool`, el firmware arrancó `sda`. Reinicia y elige `sdb` otra vez. Si `sdb` no arranca para nada, arranca `sda`: estás de vuelta en el sistema original y no se perdió nada. En UEFI eso significa la entrada "Linux Boot Manager" de `sda2` (systemd-boot) o el disco `sda` en sí en el menú de arranque del firmware (Secure Boot).

No continúes hasta que el sistema de archivos raíz en vivo esté en `newrpool`, arrancado desde `sdb`.

## Retirar el pool viejo {#retire-the-old-pool}

Las variables del shell se perdieron con el reinicio. Vuelve a cargarlas y asegúrate de que ninguna haya quedado vacía:

{% highlight shell %}
BK=$(cat /root/.last-rpool-shrink-backup)
. "$BK/vars.sh"
echo "${OLDPOOL:?} ${NEWPOOL:?} ${SDA:?} ${SDA3:?} ${SDB:?} ${SDB3:?}"
{% endhighlight %}

Aquí `/root` es la copia que vino con el snapshot final, así que tiene el puntero al directorio de backup.

Ahora demuestra que el disco que estás por borrar no es desde el que estás corriendo. El nuevo pool debe contener la ruta de `sdb` y no debe contener la de `sda`:

{% highlight shell %}
zpool status -P "$NEWPOOL"
zpool status -P "$NEWPOOL" | grep -F -- "$SDB3"
zpool status -P "$NEWPOOL" | grep -F -- "$SDA" && echo "STOP: sda is part of $NEWPOOL"
{% endhighlight %}

El segundo comando debe imprimir la línea de `sdb3`; el tercero no debe imprimir nada.

Después asegúrate de que el pool viejo no esté importado y de que nada esté usando el disco viejo:

{% highlight shell %}
zpool list
zpool export "$OLDPOOL"
lsblk -o NAME,PATH,FSTYPE,MOUNTPOINTS "$SDA"
{% endhighlight %}

Si `rpool` aparece en `zpool list`, el export tiene que funcionar. Si no se exporta, o si algo en `sda` está montado, detente y averigua por qué. Con el nuevo archivo de caché, `rpool` normalmente ni siquiera se importa al arrancar, y el export simplemente reporta que el pool no existe.

## Reparticionar sda y volver a adjuntarlo {#repartition-sda-and-reattach-it}

El sistema está corriendo desde el nuevo pool de 50GB en `sdb3`, y el pool viejo está cerrado. Hasta este punto, arrancar `sda` desde el menú de la BIOS todavía traería de vuelta el sistema original. El próximo comando termina con eso.

Borra la etiqueta ZFS vieja, sin ocultar errores:

{% highlight shell %}
zpool labelclear -f "$SDA3"
{% endhighlight %}

Si esto falla porque el dispositivo está en uso, vuelve al paso anterior; algo todavía tiene abierto el pool viejo.

Reparticiona el disco `sda`:

{% highlight shell %}
sgdisk --zap-all "$SDA"
sgdisk -a1 -n1:34:2047 -t1:EF02 "$SDA"
sgdisk -n2:2048:+1G -t2:EF00 "$SDA"
sgdisk -n3:0:+50G -t3:BF01 "$SDA"
partx -u "$SDA"
udevadm settle

sgdisk -v "$SDA"
sgdisk -p "$SDA"
lsblk -o NAME,SIZE,PARTTYPENAME "$SDA"
{% endhighlight %}

Adjunta el nuevo `sda3` como segundo lado del mirror:

{% highlight shell %}
zpool attach -f "$NEWPOOL" "$SDB3" "$SDA3"
{% endhighlight %}

Observa el resilver:

{% highlight shell %}
watch -n 5 zpool status "$NEWPOOL"
{% endhighlight %}

Espera a que termine el resilver.

## Recrear la partición de arranque de sda {#recreate-the-sda-boot-partition}

Una vez que `sda3` forma parte del mirror, recrea la partición de arranque en `sda2` y regístrala. `proxmox-boot-tool clean` descarta de la lista cualquier UUID cuya partición ya no exista:

{% highlight shell %}
ESP_SDA=$(readlink -f "$SDA-part2")
echo "$ESP_SDA"

proxmox-boot-tool format "$ESP_SDA" --force
udevadm settle
proxmox-boot-tool init "$ESP_SDA" $INIT_MODE
proxmox-boot-tool clean
proxmox-boot-tool refresh
proxmox-boot-tool status
{% endhighlight %}

`proxmox-boot-tool status` debería listar dos particiones, una en cada disco, ambas configuradas de la misma manera (`grub` o `uefi`). Si lista solo una, `init` registró un UUID obsoleto (la misma condición de carrera de udev que en `sdb2`) y `clean` lo descartó: ejecuta `udevadm settle` y luego `init` y `refresh` otra vez.

**UEFI:** el reparticionado le dio a `sda2` un nuevo UUID de partición, así que la entrada del firmware para el `sda2` viejo ahora no apunta a nada, y con systemd-boot tampoco la del `sdb2` original. Elimina toda entrada de arranque de estos cargadores cuyo UUID de partición no sea uno de las dos particiones de arranque actuales:

{% highlight shell %}
KEEP="$(blkid -s PARTUUID -o value "$SDA-part2" "$SDB-part2")"
echo "$KEEP"
efibootmgr -v | grep -E '^Boot[0-9A-F]{4}\* (Linux Boot Manager|proxmox)' |
while read -r line; do
  n=${line:4:4}
  u=$(echo "$line" | grep -oiE 'GPT,[0-9a-f-]{36}' | cut -d, -f2)
  echo "$KEEP" | grep -qi -- "$u" || { echo "removing stale Boot$n ($u)"; efibootmgr -q -b "$n" -B; }
done
efibootmgr -v | grep -E '^Boot(Order|[0-9A-F]{4}\* (Linux Boot Manager|proxmox))'
{% endhighlight %}

`echo "$KEEP"` debe imprimir dos UUID antes de que confíes en el bucle; si imprime menos, no lo ejecutes. El bucle solo mira las entradas llamadas "Linux Boot Manager" o "proxmox", y deja en paz las entradas de otros sistemas operativos y las del propio firmware.

Lo que queda depende del cargador. Con systemd-boot, terminas con una entrada "Linux Boot Manager" por disco. Con GRUB y Secure Boot, `init` movió la única entrada "proxmox" a `sda2`, y `sdb` arranca a través de su copia en la ruta de medios extraíbles, exactamente como en una instalación nueva. Si prefieres tener una entrada con nombre para cada disco, agrega una para `sdb`:

{% highlight shell %}
efibootmgr -c -d "$SDB" -p 2 -L "proxmox (sdb)" -l '\EFI\proxmox\shimx64.efi'
{% endhighlight %}

Algunos firmwares, incluido el de mis VMs de prueba, borran silenciosamente las entradas de arranque de discos que no están presentes al arrancar. Si una entrada desaparece después de las pruebas con un solo disco que siguen, `proxmox-boot-tool reinit` las restaura: con systemd-boot recrea una entrada por partición de arranque; con Secure Boot vuelve a apuntar "proxmox" a la última partición de la lista.

> **Nota de campo: `mkfs.vfat` colgado en `sda2`**
>
> En una de las ejecuciones, `mkfs.vfat` quedó trabado en E/S no interrumpible mientras formateaba `sda2`. El resilver de ZFS igual terminó correctamente, pero el formateador nunca volvió. Esa ejecución todavía no exportaba el pool viejo ni verificaba el borrado de la etiqueta, así que la causa más probable es que `rpool` seguía importado cuando se reparticionó su disco. Por eso el procedimiento ahora retira explícitamente el pool viejo primero. Las verificaciones útiles fueron:

{% highlight shell %}
ps -o pid,ppid,stat,wchan:32,cmd -C mkfs.vfat
zpool status newrpool
zpool list
dmesg | tail -100
lsblk -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINTS "$SDA" "$SDB"
{% endhighlight %}

Si esto pasa, primero confirma que el sistema está corriendo desde `newrpool`, que `sdb2` ya es booteable y que el mirror ZFS está sano o al menos se entiende su estado. Después reinicia y vuelve a intentar el paso de `proxmox-boot-tool` para `sda2`.

## Scrub y verificación final {#scrub-and-final-verification}

Limpia los contadores transitorios y ejecuta un scrub:

{% highlight shell %}
zpool clear "$NEWPOOL"
zpool scrub "$NEWPOOL"

while zpool status "$NEWPOOL" | grep -q "scrub in progress"; do
  zpool status "$NEWPOOL"
  sleep 5
done
{% endhighlight %}

Verificaciones finales:

{% highlight shell %}
cat /proc/cmdline
findmnt -n -o SOURCE /

zpool status -v "$NEWPOOL"
zpool list -v "$NEWPOOL"

proxmox-boot-tool status
efibootmgr -v    # UEFI only

systemctl is-active proxmox-backup proxmox-backup-proxy ssh

sgdisk -p "$SDA"
sgdisk -p "$SDB"
{% endhighlight %}

El estado final debería verse así:

{% highlight text %}
/ mounted from newrpool/ROOT/pbs-1

newrpool ONLINE
  mirror-0 ONLINE
    sdb3 50G ONLINE
    sda3 50G ONLINE

/dev/sda3 50.0 GiB BF01
/dev/sdb3 50.0 GiB BF01

proxmox-backup active
proxmox-backup-proxy active
ssh active
{% endhighlight %}

Un pool en mirror no es lo mismo que un arranque en mirror. La última prueba es arrancar desde cada disco por separado: reinicia, elige `sda` en el menú de arranque del firmware (o con `efibootmgr --bootnext`), ejecuta las verificaciones de arriba; reinicia de nuevo, elige `sdb` y repite. Desconectar físicamente el otro disco es una prueba más sólida, si puedes; eso es lo que hice en las VMs de prueba. Si ambos terminan en `newrpool/ROOT/pbs-1`, cualquiera de los discos puede morir sin llevarse el servidor consigo. Hasta entonces, la migración no está terminada.

## Notas de rollback {#rollback-notes}

El directorio de backup contiene:

- Backups de GPT de ambos discos.
- Listados de propiedades y datasets ZFS.
- Un stream recursivo de ZFS send del `rpool` original, más el nombre de su snapshot.
- Un tarball con la configuración importante del sistema.
- Las variables guardadas para la segunda mitad del procedimiento.
- Checksums de los artefactos.

Cómo hacer el rollback depende de hasta dónde llegaste:

- **Antes de `zpool labelclear` en `sda3`:** el sistema original está intacto en `sda`. Su pool, su partición de arranque, su configuración de GRUB y su archivo de caché nunca se tocaron. Elige `sda` en el menú de arranque del firmware y arranca `rpool` como antes. Todo lo que se haya escrito después del snapshot final vive solo en `newrpool`, pero con los servicios de PBS detenidos durante la sincronización, eso debería ser prácticamente nada.
- **Después de reparticionar `sda`:** ambos discos son nuevos. Si `newrpool` está roto en ese punto, recuperar implica arrancar con medios de rescate, crear un pool adecuado, recibir el stream ZFS guardado y reinstalar el gestor de arranque.

Lo importante no son los comandos exactos. Lo importante es el orden:

1. Verificar la distribución.
2. Crear y verificar el backup.
3. Reconstruir un lado del mirror como un pool más chico.
4. Replicar root.
5. Arrancar desde el disco nuevo, elegido a propósito.
6. Retirar el pool viejo, luego destruir y volver a adjuntar el otro lado del mirror.
7. Hacer scrub y luego arrancar desde cada disco por separado.
