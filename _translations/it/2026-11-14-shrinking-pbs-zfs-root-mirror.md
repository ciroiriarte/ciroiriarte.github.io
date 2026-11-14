---
title: "Ridurre un mirror ZFS di root su Proxmox Backup Server"
description: "Una procedura sul campo per ridurre partizioni di root ZFS in mirror sovradimensionate su Proxmox Backup Server, ricostruendo un lato del mirror alla volta e mantenendo un fallback avviabile fino alla fine. Testata con BIOS legacy, UEFI con systemd-boot e UEFI con Secure Boot."
lang: it
date: 2026-11-14 13:00:00 -0300
permalink: /it/2026/11/14/shrinking-pbs-zfs-root-mirror.html
categories:
  - storage-backup
tags:
  - pbs
  - zfs
---

Dopo aver installato Proxmox Backup Server su una coppia di SSD da 200GB con una root ZFS in mirror (`rpool`), mi sono accorto che il filesystem di root usava meno di 3GB. Volevo recuperare lo spazio rimanente per un altro uso, ma ZFS non supporta la riduzione in place dei vdev di primo livello né dei pool. Troncare direttamente le partizioni GPT sottostanti è il modo in cui i pool si corrompono.

L'approccio che ho usato è una migrazione progressiva del mirror: staccare un lato del mirror, costruire su quel disco un pool più piccolo da 50GB, replicarci il filesystem di root, avviare dal nuovo pool e infine ripartizionare e riattaccare il secondo disco per ripristinare il mirror. Il vecchio disco resta intatto, e avviabile, finché il nuovo non ha dimostrato di saper avviare da solo.

Tutto avviene sul sistema in esecuzione; non ho mai dovuto avviare un supporto di ripristino. Tienilo comunque a portata di mano.

<!--more-->

## Fa al caso tuo? {#does-this-apply-to-you}

Questa procedura è stata scritta per un setup piuttosto specifico, ed eseguita su di esso. Verifica che il tuo corrisponda prima di andare avanti:

- Uno dei tre setup di avvio gestiti da `proxmox-boot-tool`. Il mio server avvia in BIOS legacy con GRUB; la procedura funziona anche su UEFI, con alcune differenze descritte più avanti.
- Nessuna cifratura nativa ZFS sul pool di root.
- Il layout predefinito dell'installer: root su `rpool/ROOT/pbs-1`. Se `findmnt -n -o SOURCE /` mostra un dataset diverso, sostituiscilo ovunque qui sotto.
- Accesso SSH come root più accesso alla console out-of-band (iLO, IPMI, seriale, crash cart), perché potresti aver bisogno del menu di avvio del firmware.

Per capire quale setup di avvio hai, guarda la prima riga di `proxmox-boot-tool status` e con cosa è "configured with" ciascuna partizione di avvio, e su UEFI controlla Secure Boot:

{% highlight shell %}
proxmox-boot-tool status
mokutil --sb-state
{% endhighlight %}

| Setup di avvio | `proxmox-boot-tool status` | Boot loader | `INIT_MODE` più avanti |
|---|---|---|---|
| BIOS legacy | avviato con `legacy`, partizioni `grub` | GRUB | `grub` |
| UEFI | avviato con `uefi`, partizioni `uefi` | systemd-boot | vuoto |
| UEFI con Secure Boot | avviato con `uefi`, partizioni `grub` | GRUB, caricato dallo shim firmato | `grub` |

La parte ZFS della procedura è identica per tutti e tre. Su UEFI cambia il modo in cui scegli quale disco avvia, e il fatto che il firmware mantiene una propria lista di voci di avvio, ognuna delle quali punta a una partizione specifica, che va riordinata dopo il ripartizionamento dei dischi. Questi passaggi sono contrassegnati con **UEFI**.

Dopo la prima esecuzione su hardware reale, ho ripetuto l'intera procedura, così come è scritta qui, su VM nuove di Proxmox Backup Server 4.2 con root ZFS RAID1: una su SeaBIOS, una su UEFI con systemd-boot e una su UEFI con Secure Boot attivo. Ogni esecuzione ha coperto la sincronizzazione base e incrementale, il primo avvio dal nuovo disco, un avvio di rollback dal vecchio, la ricostruzione del secondo disco e un avvio da ciascun disco con l'altro rimosso; Secure Boot è rimasto attivo per tutto il tempo. Due dei passaggi qui sotto, lo svuotamento anticipato della lista delle partizioni di avvio e le chiamate a `udevadm settle`, ci sono perché la prima ripetizione è fallita senza di essi.

## Punto di partenza {#starting-point}

L'host era un Proxmox Backup Server con un pool di root ZFS in mirror:

{% highlight text %}
rpool
  mirror-0
    /dev/sda3
    /dev/sdb3
{% endhighlight %}

I due dischi di avvio erano più o meno così:

{% highlight text %}
/dev/sda1   BIOS boot partition
/dev/sda2   EFI System Partition, used by proxmox-boot-tool with GRUB
/dev/sda3   ZFS member, around 185G

/dev/sdb1   BIOS boot partition
/dev/sdb2   EFI System Partition, used by proxmox-boot-tool with GRUB
/dev/sdb3   ZFS member, around 185G
{% endhighlight %}

Il sistema era avviato in modalità BIOS legacy, ma usava comunque il flusso di lavoro di Proxmox boot-tool per gestire le partizioni di avvio:

{% highlight shell %}
proxmox-boot-tool status
{% endhighlight %}

L'obiettivo era portare entrambe le partizioni di root ZFS a 50GB:

{% highlight text %}
/dev/sda3   50G
/dev/sdb3   50G
{% endhighlight %}

Questa procedura lascia intenzionalmente il pool sostitutivo con il nome `newrpool`. Rinominare un pool di root di nuovo in `rpool` significa esportarlo e reimportarlo da un ambiente offline e aggiornare la configurazione di avvio; è un lavoro a parte, e non vale la pena mescolarlo con la riduzione. Ho lasciato il nome così com'è.

## Avvertenze importanti {#important-warnings}

È un'operazione distruttiva.

Prima di fare qualcosa del genere, assicurati di avere:

- Accesso out-of-band alla console e al menu di avvio del firmware.
- Una destinazione di backup fuori dal pool di root.
- La mappatura dei dischi verificata, tramite numero di serie, per entrambi i dischi.
- Un backup verificato, non solo un comando di backup che sembrava essere andato a buon fine.
- Sufficiente dimestichezza con i supporti di ripristino per recuperare un sistema Proxmox con root ZFS se l'avvio fallisce.

Non installare aggiornamenti mentre la procedura è in corso: un aggiornamento del kernel esegue `proxmox-boot-tool refresh` e tocca tutte le partizioni di avvio registrate.

Non incollare i comandi alla cieca. Adatta nomi dei pool, nomi dei dataset e percorsi by-id al tuo sistema, e leggi l'output di ogni passaggio prima di eseguire il successivo.

## Ispezionare il sistema {#inspect-the-system}

Inizia raccogliendo il layout reale.

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

Conferma che la root sia davvero su ZFS e che `sda3` e `sdb3` siano i membri del vdev di root in mirror. Controlla anche se ci sono dataset aggiuntivi nel pool di root, swap su uno zvol, o proprietà insolite come `canmount`, `mountpoint`, `quota` o `refreservation`; la replica le conserverà, ma è meglio scoprire le sorprese qui che dopo il riavvio.

Identifica i percorsi stabili dei dischi prima di toccare qualsiasi cosa:

{% highlight shell %}
ls -l /dev/disk/by-id/ | grep -E 'sda|sdb'
{% endhighlight %}

I nomi del kernel come `/dev/sda` possono scambiarsi tra un avvio e l'altro, e questa procedura riavvia a metà. Ogni comando distruttivo qui sotto usa percorsi `/dev/disk/by-id/`, sia per ZFS sia per `sgdisk`.

## Creare un backup {#create-a-backup}

Come destinazione del backup ho usato un altro datastore ZFS montato su `/mnt/datastore/backup01`.

{% highlight shell %}
TS=$(date +%Y%m%d-%H%M%S)
BK=/mnt/datastore/backup01/rpool-shrink-$TS
mkdir -p "$BK"
echo "$BK" > /root/.last-rpool-shrink-backup
{% endhighlight %}

Cattura lo stato attuale:

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

Crea un backup prudente, a livello di filesystem, dei percorsi di sistema importanti:

{% highlight shell %}
umask 077

tar --xattrs --acls --one-file-system \
  -czf "$BK/etc-root-boot-varlibpbs.tar.gz" \
  /etc /root /boot /var/lib/proxmox-backup \
  2> "$BK/tar-warnings.txt" || true
{% endhighlight %}

Ora crea il backup per replica ZFS. Il dry run iniziale ti dice quanto è grande lo stream ricorsivo, snapshot inclusi; deve entrare comodamente nel nuovo pool da 50GB, non solo i 3GB della root attiva:

{% highlight shell %}
SN="pre-shrink-$TS"
zfs snapshot -r "rpool@$SN"
zfs send -nvR "rpool@$SN" | tail -1

zfs send -R "rpool@$SN" > "$BK/rpool-$SN.zfs"
echo "$SN" > "$BK/base-snapshot-name.txt"
sha256sum "$BK"/* > "$BK/SHA256SUMS"
sync
{% endhighlight %}

Verifica i checksum prima di continuare:

{% highlight shell %}
cd "$BK"
sha256sum -c SHA256SUMS
zfs list -t snapshot -r rpool | grep "$SN"
{% endhighlight %}

Se la verifica dei checksum fallisce, fermati.

Più avanti il nuovo pool viene popolato a partire da questo file anziché direttamente da `zfs send`. È voluto: il receive fa anche da test di ripristino dello stream di backup, prima di qualsiasi operazione irreversibile.

## Staccare un lato del mirror {#detach-one-side-of-the-mirror}

La strategia è tenere la macchina in funzione su un lato del vecchio mirror mentre ricostruiamo l'altro lato come un nuovo pool più piccolo.

Nel mio caso ho staccato per primo il lato `sdb`.

Imposta le variabili in base al tuo hardware, usando i percorsi by-id del disco intero identificati prima, e salvale accanto al backup. La shell le dimentica al riavvio, e la seconda metà della procedura ne ha bisogno:

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

Se `zfs list` o `ls` falliscono, fermati: lo snapshot e il file dello stream devono corrispondere. Imposta `INIT_MODE` in base alla tabella qui sopra; è l'unica impostazione che dipende da come avvia la macchina.

Stacca `sdb3` dal vecchio pool di root e conferma che `rpool` ora è su un singolo disco:

{% highlight shell %}
zpool detach "$OLDPOOL" "${SDB3:?}"
zpool status -P "$OLDPOOL"
{% endhighlight %}

`zpool status` dovrebbe elencare solo il percorso di `sda3`. A questo punto il vecchio `rpool` non è più in mirror. Non togliere l'alimentazione a meno di essere sicuro che backup e accesso alla console siano a posto.

## Ripartizionare sdb {#repartition-sdb}

Cancella e ricrea il layout delle partizioni sul disco `sdb`, con la partizione 3 da 50GB:

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

La prima partizione è la minuscola BIOS boot partition. La seconda è la EFI System Partition usata da `proxmox-boot-tool`. La terza è la nuova partizione ZFS da 50GB. `sgdisk -v` non dovrebbe segnalare problemi e `lsblk` dovrebbe mostrare le tre partizioni con le dimensioni previste; altrimenti fermati qui, finché il vecchio pool è ancora intatto su `sda`.

## Creare il nuovo pool più piccolo {#create-the-new-smaller-pool}

Crea il nuovo pool sulla partizione `sdb3`, più piccola:

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

`-R` imposta una root alternativa, così niente del nuovo pool viene montato sopra il sistema in esecuzione. Tiene anche il nuovo pool fuori dal `/etc/zfs/zpool.cache` del sistema attivo; la nuova root riceve il proprio file di cache più avanti.

Ricevi lo snapshot base nel nuovo pool. `-u` lascia per ora smontati i dataset ricevuti:

{% highlight shell %}
zfs receive -u -F -d "$NEWPOOL" < "$BK/rpool-$SN_BASE.zfs"
zfs list -r "$NEWPOOL"
zfs list "$NEWPOOL/ROOT/pbs-1"
{% endhighlight %}

## Sincronizzazione incrementale finale {#final-incremental-sync}

Prima della sincronizzazione finale, assicurati che PBS non sia nel mezzo di qualcosa, poi ferma i servizi che scrivono sul pool di root:

{% highlight shell %}
proxmox-backup-manager task list

systemctl stop proxmox-backup-proxy proxmox-backup
systemctl is-active proxmox-backup-proxy proxmox-backup
sync
{% endhighlight %}

Aspetta prima che finiscano i task di backup, sync, verify o garbage collection in corso. Entrambi i servizi devono risultare `inactive`; se uno dei due è ancora in esecuzione, non fare lo snapshot finale.

Crea e invia lo snapshot incrementale finale:

{% highlight shell %}
FINAL_SN="shrink-final-$(date +%Y%m%d-%H%M%S)"

zfs snapshot -r "$OLDPOOL@$FINAL_SN"
zfs send -R -I "$OLDPOOL@$SN_BASE" "$OLDPOOL@$FINAL_SN" | zfs receive -u -F -d "$NEWPOOL"

echo "$FINAL_SN" > "$BK/final-snapshot-name.txt"
zfs list -r "$NEWPOOL" > "$BK/newrpool-after-final-recv.txt"
{% endhighlight %}

Imposta il dataset di avvio e i mountpoint, poi monta esplicitamente la nuova root sotto l'altroot:

{% highlight shell %}
zpool set bootfs="$NEWPOOL/ROOT/pbs-1" "$NEWPOOL"
zfs set mountpoint=/ "$NEWPOOL/ROOT/pbs-1"
zfs set mountpoint="/$NEWPOOL" "$NEWPOOL"
zfs set mountpoint="/$NEWPOOL/ROOT" "$NEWPOOL/ROOT"

findmnt /mnt/newrpool >/dev/null || zfs mount "$NEWPOOL/ROOT/pbs-1"
findmnt -n -o SOURCE /mnt/newrpool
{% endhighlight %}

L'ultimo comando deve stampare `newrpool/ROOT/pbs-1`. Un semplice `test -d /mnt/newrpool/etc` non basta: se il dataset non è montato, i passaggi successivi scriverebbero in una directory vuota sulla vecchia root.

## Preparare la nuova root all'avvio {#prepare-the-new-root-to-boot}

Fai puntare la riga di comando del kernel della nuova root a `newrpool`. Cambia solo il valore di `root=ZFS=`; tutto il resto della riga di comando del kernel, come una console seriale, rimane. GRUB legge `/etc/default/grub.d/zfs.cfg`; systemd-boot legge `/etc/kernel/cmdline`. Un'installazione nuova li ha entrambi, qualunque sia la modalità di avvio, quindi entrambi ricevono la stessa modifica e non possono divergere:

{% highlight shell %}
grep -n 'root=ZFS=' /mnt/newrpool/etc/default/grub.d/zfs.cfg /mnt/newrpool/etc/default/grub

sed -i "s|root=ZFS=$OLDPOOL/|root=ZFS=$NEWPOOL/|" /mnt/newrpool/etc/default/grub.d/zfs.cfg
[ -f /mnt/newrpool/etc/kernel/cmdline ] && \
  sed -i "s|root=ZFS=$OLDPOOL/|root=ZFS=$NEWPOOL/|" /mnt/newrpool/etc/kernel/cmdline

grep -rn 'root=ZFS=' /mnt/newrpool/etc/default/grub.d/zfs.cfg /mnt/newrpool/etc/kernel/cmdline 2>/dev/null

# Keep the same ZFS host identity after booting the received root.
cp /etc/hostid /mnt/newrpool/etc/hostid
{% endhighlight %}

Il primo `grep` mostra dove si trova l'argomento root sul tuo sistema; sul mio era in `/etc/default/grub.d/zfs.cfg`, più `/etc/kernel/cmdline` sulle macchine di test UEFI. Dopo la modifica, ogni corrispondenza dovrebbe riportare `root=ZFS=newrpool/ROOT/pbs-1`.

Dai alla nuova root un file di cache ZFS che elenchi solo `newrpool`. La copia arrivata con lo snapshot è quella del vecchio sistema, ed elenca ancora `rpool`; avviare con quella importerebbe il vecchio pool accanto al nuovo:

{% highlight shell %}
rm -f /mnt/newrpool/etc/zfs/zpool.cache
zpool set cachefile=/mnt/newrpool/etc/zfs/zpool.cache "$NEWPOOL"
zdb -C -U /mnt/newrpool/etc/zfs/zpool.cache | grep -E "^[^ ]|name:"
{% endhighlight %}

L'output di `zdb` dovrebbe menzionare `newrpool` e nient'altro.

Fai il bind mount dei filesystem di runtime per il chroot:

{% highlight shell %}
for d in dev proc sys run; do
  mountpoint -q "/mnt/newrpool/$d" || mount --rbind "/$d" "/mnt/newrpool/$d"
  mount --make-rslave "/mnt/newrpool/$d"
done
{% endhighlight %}

**UEFI:** il bind ricorsivo di `/sys` porta nel chroot anche `/sys/firmware/efi/efivars`. `proxmox-boot-tool init` ne ha bisogno lì per creare la voce di avvio del firmware per il nuovo disco; `ls /mnt/newrpool/sys/firmware/efi/efivars | head -1` dovrebbe elencare qualcosa.

Ora rigenera l'initramfs e configura la partizione di avvio su `sdb2`. Anche la lista delle partizioni di avvio della nuova root (`/etc/kernel/proxmox-boot-uuids`) è arrivata con lo snapshot, quindi nomina ancora `sda2`. Svuotala prima, prima che qualsiasi cosa venga eseguita nel chroot: `update-initramfs` scatena un `proxmox-boot-tool refresh` attraverso i suoi hook, e con la vecchia lista quel refresh riscrive `sda2` per avviare `newrpool`. È esattamente quello che è successo nella mia prima esecuzione di prova, e ti toglie silenziosamente la via del ritorno.

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

I due UUID alla fine devono coincidere, e il file deve contenere solo quello. `udevadm settle` è importante: senza, `init` può leggere da udev il vecchio UUID della partizione prima che compaia quello appena formattato, registrare quello e poi saltare la partizione quando copia i kernel. `init` esegue già un refresh, quindi non servono un `update-grub` o un `refresh` separati. `$INIT_MODE` è volutamente senza virgolette, così quando è vuoto `init` non riceve alcun argomento di modalità.

**UEFI:** su UEFI, `init` scrive anche una voce di avvio del firmware, e i due loader lo fanno in modo diverso. Guarda il risultato, associando le voci ai dischi tramite UUID di partizione:

{% highlight shell %}
blkid -s PARTUUID -o value "$SDA-part2" "$SDB-part2"
efibootmgr -v | grep -E '^Boot(Order|[0-9A-F]{4}\* (Linux Boot Manager|proxmox))'
{% endhighlight %}

- **systemd-boot** aggiunge una nuova voce "Linux Boot Manager" per `sdb2` e la mette per prima nell'ordine di avvio. La voce per `sda2` rimane, accanto a una obsoleta per il vecchio `sdb2`, che non esiste più; quella viene rimossa alla fine.
- **GRUB con Secure Boot** mantiene un'unica voce chiamata "proxmox", e `init` la sposta su `sdb2`. `sda` non perde la sua via del ritorno: ogni partizione di avvio riceve anche una copia del loader nel percorso per supporti rimovibili, `\EFI\BOOT\BOOTX64.EFI`, che è ciò che il firmware esegue quando scegli il disco stesso dal suo menu di avvio. È così che il mio test di rollback ha avviato il vecchio disco.

Controlla che l'initramfs abbia incluso il nuovo file di cache:

{% highlight shell %}
lsinitramfs /mnt/newrpool/boot/initrd.img-$(uname -r) | grep zpool.cache
{% endhighlight %}

Niente del sistema in esecuzione cambia in questa sezione. La sua configurazione di GRUB, il suo file di cache e la sua lista di partizioni di avvio descrivono ancora `rpool`, quindi `sda` resta una via del ritorno funzionante.

Verifica entrambe le partizioni di avvio: `sdb2` deve avere un kernel e una configurazione di GRUB che punta a `newrpool`, e `sda2` deve puntare ancora a `rpool`:

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

Il `grep` cerca nell'intera partizione, quindi trova la riga di comando del kernel ovunque il boot loader la tenga: `grub/grub.cfg` per GRUB, `loader/entries/` per systemd-boot. Su `sdb2` dovresti vedere i file del kernel e dell'initrd e `root=ZFS=newrpool/ROOT/pbs-1`; su `sda2`, `root=ZFS=rpool/ROOT/pbs-1` e nessuna menzione di `newrpool`. GRUB aggiunge anche un generico `root=ZFS=/ROOT/pbs-1` su entrambe; è normale, e vince il valore specifico che viene dopo. Se `sda2` menziona `newrpool`, è stata reindirizzata: esegui `proxmox-boot-tool refresh` sul sistema attivo per rimetterla a posto prima di andare oltre.

Infine, smonta il chroot:

{% highlight shell %}
umount -R /mnt/newrpool
{% endhighlight %}

Qui non esporto `newrpool`. I demoni che girano nei propri mount namespace, come `systemd-udevd`, `systemd-logind` e `chronyd`, mantengono copie dei mount del chroot, e `zpool export` si rifiuta con "pool is busy". Non importa: il riavvio chiude il pool, e con lo stesso host ID l'initramfs lo importa senza lamentarsi.

## Avviare dal nuovo disco {#boot-from-the-new-disk}

`sda` avvia ancora il vecchio pool. È proprio questo il punto: il primo avvio deve venire da `sdb` di proposito, altrimenti non dimostra nulla su `sdb`.

Su BIOS legacy, il firmware avvia ancora da `sda` per impostazione predefinita. Riavvia e, dalla console, scegli il disco `sdb` nel menu di avvio una tantum del BIOS:

{% highlight shell %}
sync
systemctl reboot
{% endhighlight %}

**UEFI:** qui non ti serve la console. Indica al firmware quale voce usare solo per il prossimo avvio, quella che punta a `sdb2`:

{% highlight shell %}
P=$(blkid -s PARTUUID -o value "$SDB-part2")
efibootmgr -v | grep -i -- "$P"
N=$(efibootmgr -v | grep -i -- "$P" | sed -nE 's/^Boot([0-9A-F]{4}).*/\1/p' | head -1)
efibootmgr --bootnext "${N:?no boot entry for sdb2}"
sync
systemctl reboot
{% endhighlight %}

Con systemd-boot la nuova voce è già la prima nell'ordine di avvio, quindi `--bootnext` lo rende solo esplicito. Dopo il riavvio, `efibootmgr | grep BootCurrent` ti dice quale voce il firmware ha effettivamente usato. Non tutti i firmware trattano le voci di avvio allo stesso modo: il firmware delle mie VM di test riordinava l'ordine di avvio seguendo l'ordine dei dischi della VM, quindi un semplice riavvio tornava su `sda`. Fidati di `BootCurrent` e `findmnt`, non dell'ordine che ti aspettavi.

Quando l'host torna su, verifica che la root sia ora montata da `newrpool`:

{% highlight shell %}
cat /proc/cmdline
findmnt -n -o SOURCE /
zpool status -v newrpool
zpool list -v newrpool
{% endhighlight %}

Risultato atteso:

{% highlight text %}
root=ZFS=newrpool/ROOT/pbs-1
newrpool/ROOT/pbs-1
newrpool  49.5G  ONLINE
{% endhighlight %}

Se invece sei finito su `rpool`, il firmware ha avviato `sda`. Riavvia e scegli di nuovo `sdb`. Se `sdb` non avvia affatto, avvia `sda`: sei di nuovo sul sistema originale, e non hai perso nulla. Su UEFI questo significa la voce "Linux Boot Manager" per `sda2` (systemd-boot) oppure il disco `sda` stesso nel menu di avvio del firmware (Secure Boot).

Non continuare finché il filesystem di root attivo non è su `newrpool`, avviato da `sdb`.

## Ritirare il vecchio pool {#retire-the-old-pool}

Dopo il riavvio le variabili della shell sono sparite. Ricaricale e assicurati che nessuna sia tornata vuota:

{% highlight shell %}
BK=$(cat /root/.last-rpool-shrink-backup)
. "$BK/vars.sh"
echo "${OLDPOOL:?} ${NEWPOOL:?} ${SDA:?} ${SDA3:?} ${SDB:?} ${SDB3:?}"
{% endhighlight %}

Qui `/root` è la copia arrivata con lo snapshot finale, quindi contiene il puntatore alla directory di backup.

Ora dimostra che il disco che stai per cancellare non è quello da cui stai girando. Il nuovo pool deve contenere il percorso di `sdb` e non deve contenere quello di `sda`:

{% highlight shell %}
zpool status -P "$NEWPOOL"
zpool status -P "$NEWPOOL" | grep -F -- "$SDB3"
zpool status -P "$NEWPOOL" | grep -F -- "$SDA" && echo "STOP: sda is part of $NEWPOOL"
{% endhighlight %}

Il secondo comando deve stampare la riga di `sdb3`; il terzo non deve stampare nulla.

Poi assicurati che il vecchio pool non sia importato e che niente stia usando il vecchio disco:

{% highlight shell %}
zpool list
zpool export "$OLDPOOL"
lsblk -o NAME,PATH,FSTYPE,MOUNTPOINTS "$SDA"
{% endhighlight %}

Se `rpool` compare in `zpool list`, l'export deve riuscire. Se non si esporta, o se qualcosa su `sda` è montato, fermati e scopri perché. Con il nuovo file di cache, normalmente `rpool` non viene affatto importato all'avvio, e l'export si limita a segnalare che il pool non esiste.

## Ripartizionare sda e riattaccarlo {#repartition-sda-and-reattach-it}

Il sistema gira dal nuovo pool da 50GB su `sdb3`, e il vecchio pool è chiuso. Fino a questo punto, avviare `sda` dal menu del BIOS riporterebbe ancora il sistema originale. Il prossimo comando mette fine a questa possibilità.

Cancella la vecchia etichetta ZFS, senza nascondere gli errori:

{% highlight shell %}
zpool labelclear -f "$SDA3"
{% endhighlight %}

Se fallisce perché il dispositivo è in uso, torna al passaggio precedente; qualcosa tiene ancora aperto il vecchio pool.

Ripartiziona il disco `sda`:

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

Attacca il nuovo `sda3` come secondo lato del mirror:

{% highlight shell %}
zpool attach -f "$NEWPOOL" "$SDB3" "$SDA3"
{% endhighlight %}

Osserva il resilver:

{% highlight shell %}
watch -n 5 zpool status "$NEWPOOL"
{% endhighlight %}

Aspetta che il resilver finisca.

## Ricreare la partizione di avvio di sda {#recreate-the-sda-boot-partition}

Una volta che `sda3` fa parte del mirror, ricrea la partizione di avvio su `sda2` e registrala. `proxmox-boot-tool clean` elimina dalla lista ogni UUID la cui partizione non esiste più:

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

`proxmox-boot-tool status` dovrebbe elencare due partizioni, una per disco, entrambe configurate allo stesso modo (`grub` o `uefi`). Se ne elenca solo una, `init` ha registrato un UUID obsoleto (la stessa race di udev vista su `sdb2`) e `clean` l'ha scartato: esegui `udevadm settle`, poi di nuovo `init` e `refresh`.

**UEFI:** il ripartizionamento ha dato a `sda2` un nuovo UUID di partizione, quindi la voce del firmware per il vecchio `sda2` ora non punta a nulla, e con systemd-boot lo stesso vale per quella del `sdb2` originale. Rimuovi ogni voce di avvio di questi loader il cui UUID di partizione non sia uno delle due partizioni di avvio attuali:

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

`echo "$KEEP"` deve stampare due UUID prima che tu possa fidarti del ciclo; se ne stampa meno, non eseguirlo. Il ciclo considera solo le voci chiamate "Linux Boot Manager" o "proxmox", e lascia stare le voci di altri sistemi operativi e quelle del firmware stesso.

Ciò che resta dipende dal loader. Con systemd-boot ti ritrovi con una voce "Linux Boot Manager" per disco. Con GRUB e Secure Boot, `init` ha spostato l'unica voce "proxmox" su `sda2`, e `sdb` avvia tramite la sua copia per supporti rimovibili, esattamente come in un'installazione nuova. Se preferisci avere una voce con nome per ciascun disco, aggiungine una per `sdb`:

{% highlight shell %}
efibootmgr -c -d "$SDB" -p 2 -L "proxmox (sdb)" -l '\EFI\proxmox\shimx64.efi'
{% endhighlight %}

Alcuni firmware, incluso quello delle mie VM di test, eliminano silenziosamente le voci di avvio dei dischi assenti all'avvio. Se una voce sparisce dopo i test con un solo disco descritti più avanti, `proxmox-boot-tool reinit` le rimette a posto: con systemd-boot ricrea una voce per ogni partizione di avvio; con Secure Boot fa di nuovo puntare "proxmox" all'ultima partizione della lista.

> **Nota sul campo: `mkfs.vfat` bloccato su `sda2`**
>
> In un'esecuzione, `mkfs.vfat` è rimasto bloccato in I/O non interrompibile mentre formattava `sda2`. Il resilver ZFS si è comunque completato correttamente, ma il formattatore non è tornato. Quell'esecuzione non esportava ancora il vecchio pool né controllava la cancellazione dell'etichetta, quindi la causa più probabile è che `rpool` fosse ancora importato quando il suo disco è stato ripartizionato. Ecco perché ora la procedura ritira prima esplicitamente il vecchio pool. I controlli utili sono stati:

{% highlight shell %}
ps -o pid,ppid,stat,wchan:32,cmd -C mkfs.vfat
zpool status newrpool
zpool list
dmesg | tail -100
lsblk -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINTS "$SDA" "$SDB"
{% endhighlight %}

Se succede, conferma prima che il sistema stia girando da `newrpool`, che `sdb2` sia già avviabile e che il mirror ZFS sia sano o almeno compreso. Poi riavvia e riprova il passaggio di `proxmox-boot-tool` per `sda2`.

## Scrub e verifica finale {#scrub-and-final-verification}

Azzera eventuali contatori transitori ed esegui uno scrub:

{% highlight shell %}
zpool clear "$NEWPOOL"
zpool scrub "$NEWPOOL"

while zpool status "$NEWPOOL" | grep -q "scrub in progress"; do
  zpool status "$NEWPOOL"
  sleep 5
done
{% endhighlight %}

Controlli finali:

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

Lo stato finale dovrebbe essere questo:

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

Un pool in mirror non è la stessa cosa di un avvio in mirror. L'ultimo test è avviare da ciascun disco da solo: riavvia, scegli `sda` nel menu di avvio del firmware (o con `efibootmgr --bootnext`), esegui i controlli qui sopra; riavvia di nuovo, scegli `sdb` e ripeti. Scollegare fisicamente l'altro disco è un test più forte, se puoi farlo; è quello che ho fatto sulle VM di test. Se entrambi arrivano su `newrpool/ROOT/pbs-1`, uno qualsiasi dei due dischi può morire senza trascinare giù il server. Fino ad allora, la migrazione non è finita.

## Note sul rollback {#rollback-notes}

La directory di backup contiene:

- I backup GPT di entrambi i dischi.
- Gli elenchi delle proprietà e dei dataset ZFS.
- Uno stream ZFS send ricorsivo dell'`rpool` originale, più il nome del suo snapshot.
- Un tarball della configurazione di sistema importante.
- Le variabili salvate per la seconda metà della procedura.
- I checksum degli artefatti.

Come fare il rollback dipende da quanto sei andato avanti:

- **Prima di `zpool labelclear` su `sda3`:** il sistema originale è intatto su `sda`. Il suo pool, la sua partizione di avvio, la sua configurazione di GRUB e il suo file di cache non sono mai stati toccati. Scegli `sda` nel menu di avvio del firmware e avvierà `rpool` come prima. Tutto ciò che è stato scritto dopo lo snapshot finale vive solo su `newrpool`, ma con i servizi di PBS fermi durante la sincronizzazione, dovrebbe essere quasi nulla.
- **Dopo che `sda` è stato ripartizionato:** entrambi i dischi sono nuovi. Se a quel punto `newrpool` è rotto, il recupero significa avviare un supporto di ripristino, creare un pool adatto, ricevere lo stream ZFS salvato e reinstallare il boot loader.

La parte importante non sono i comandi esatti. La parte importante è l'ordine:

1. Verificare il layout.
2. Creare e verificare il backup.
3. Ricostruire un lato del mirror come pool più piccolo.
4. Replicare la root.
5. Avviare dal nuovo disco, scelto di proposito.
6. Ritirare il vecchio pool, poi distruggere e riattaccare l'altro lato del mirror.
7. Fare lo scrub, poi avviare da ciascun disco da solo.
