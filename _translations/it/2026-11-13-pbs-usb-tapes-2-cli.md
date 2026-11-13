---
title: "Dischi USB come nastri per Proxmox Backup Server (2/3): da riga di comando"
description: "Passo dopo passo, dalla shell. Installa mhVTL, definisci una libreria con un dock USB come mail slot, formatta i dischi come cartucce a nastro ed esegui job tape PBS cifrati e restore su di essi."
date: 2026-11-13 10:01:00 -0300
permalink: /it/datacenter/2026/11/13/pbs-usb-tapes-2-cli.html
lang: it
categories:
  - storage-backup
tags:
  - proxmox
  - pbs
  - tape
  - mhvtl
series: pbs-usb-tapes
series_part: 2
series_title: Da riga di comando
---

Nella [parte 1](/it/datacenter/2026/11/13/pbs-usb-tapes-1-why.html) ho spiegato perché potresti volere dei job tape di PBS su semplici dischi USB. Questa parte lo costruisce dalla shell: una libreria virtuale, un drive LTO-8, un dock USB che fa da mail slot della libreria e un media pool cifrato che ruota i dischi.

Ogni comando e ogni output qui sotto viene da una prova su un ambiente di test appena creato. Se preferisci cliccare, la [parte 3](/it/datacenter/2026/11/13/pbs-usb-tapes-3-gui.html) fa lo stesso dalle interfacce web.

<!--more-->

{% include series-nav.html %}

## Punto di partenza {#starting-point}

- Proxmox Backup Server 4.2 con un datastore che contiene qualche backup. Il mio si chiama `store1`.
- Un dock USB o un adattatore USB-SATA, più i dischi che vuoi ruotare. Un disco è una cartuccia.
- mhVTL `1.8.0+git20261101.7e3a101` dal mio [progetto su openSUSE Build Service](https://build.opensuse.org/project/show/home:ciriarte:mhvtl). Tutto ciò che uso qui è nel master di mhVTL ma non ancora in una release con tag, da cui lo snapshot.

Il mio ambiente di test era una VM Debian 13 con PBS installato sopra, e il "dock USB" una porta USB di un controller xHCI virtuale in cui collegavo a caldo dischi da 16 GB. Il kernel vede veri eventi di hot-plug USB, quindi mhVTL non nota la differenza. I numeri di throughput vengono da quella VM, non sono un benchmark.

I passi presuppongono un host PBS senza ancora mhVTL: sostituiscono la configurazione di esempio che il pacchetto installa. Se su quell'host hai già librerie mhVTL, aggiungi la libreria e il drive qui sotto al tuo `device.conf`.

Esegui tutto come root.

## Installare mhVTL {#install-mhvtl}

Aggiungi il repository e installa mhVTL. Il modulo del kernel viene compilato con DKMS, quindi indica esplicitamente il pacchetto degli header:

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

**Nota:** Gli header devono corrispondere al kernel in esecuzione. Se hai appena aggiornato il kernel, riavvia prima, altrimenti DKMS compila il modulo solo per il kernel che non stai ancora usando. Indica anche il metapacchetto degli header: senza, apt ha installato gli header del kernel Proxmox sulla mia macchina con kernel Debian per soddisfare `mhvtl-dkms`.

L'installazione non avvia ancora mhVTL, il che lascia il tempo per un altro passo. Il driver `ch` di Linux perde un riferimento a ogni drive ogni volta che compare un changer, quindi un drive rimosso da mhVTL non può tornare fino a un riavvio ([corretto in 7.3-rc7](https://git.kernel.org/torvalds/c/27c0f718d3b3), non presente negli attuali kernel di PBS). PBS parla con i changer tramite `/dev/sg*` e non ha bisogno di `ch`, quindi tienilo fuori:

{% highlight shell %}
echo "blacklist ch" > /etc/modprobe.d/mhvtl-no-ch.conf
# if this fails, ch is in use: reboot before going on
modprobe -r ch
{% endhighlight %}

## Definire la libreria {#define-the-library}

Il pacchetto include due librerie STK di esempio, e PBS non le vede né l'una né l'altra. PBS elenca un changer solo quando udev gli fornisce un `ID_SCSI_SERIAL`, che deriva dalla pagina VPD 0x83 dell'INQUIRY. Lo STK L700 e l'L80 che mhVTL emula fedelmente non ce l'hanno, quindi uso una personalità IBM TS3500 (`03584L22`), che ce l'ha.

Tieni una copia degli esempi, poi sostituisci `/etc/mhvtl/device.conf` con uno che contenga una libreria e un drive:

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

Non c'è una riga `Encryption:` perché AES-256-GCM è il default per i drive che lo supportano (vedi `man device.conf`). I chunk di PBS sono già compressi, quindi LZ4 è semplicemente il codec più economico da tenere abilitato.

Poi il contenuto della libreria: quattro slot di storage e due mail slot, tutti vuoti. I dischi portano con sé le proprie cartucce.

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

Elimina la seconda libreria di esempio e avvia mhVTL. Un generator di systemd costruisce le unit `vtllibrary@`/`vtltape@` a partire da `device.conf`, da cui il reload:

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

I dispositivi impiegano qualche secondo a comparire dopo il riavvio. (La mia prova mostra `/dev/sch0` perché `ch` non era ancora in blacklist. Con la blacklist attiva, quella colonna mostra `-`.)

## Associare il dock a un mail slot {#bind-the-dock-to-a-mail-slot}

`mhvtl-bay-monitor` associa la posizione fisica di un disco ai mail slot di una libreria. La posizione è il nome stabile in `/dev/disk/by-path` della porta USB, mai `/dev/sdX`. Collega un disco qualsiasi al dock e cercalo:

{% highlight shell %}
ls -l /dev/disk/by-path/ | grep usb
{% endhighlight %}

{% highlight text %}
pci-0000:00:01.0-usb-0:1:1.0-scsi-0:0:0:0 -> ../../sdb
pci-0000:00:01.0-usbv3-0:1:1.0-scsi-0:0:0:0 -> ../../sdb
{% endhighlight %}

Usa il nome `usb-` semplice. Quello `usbv3-` riporta la versione USB negoziata dal disco, quindi un disco che ripiega su USB 2 comparirebbe con un altro nome. Ogni disco collegato a questa porta finisce nello stesso bay, che è esattamente ciò che serve a una rotazione.

Associalo alla libreria 10 e avvia il monitor. La seconda colonna è il mail slot previsto; per ora la cartuccia finisce nel primo libero, che con un solo dock è sempre lo stesso:

{% highlight shell %}
BAY=/dev/disk/by-path/pci-0000:00:01.0-usb-0:1:1.0-scsi-0:0:0:0
echo "10  1  $BAY" > /etc/mhvtl/mhvtl_raw_bays.conf
systemctl enable --now mhvtl-bay-monitor
journalctl -u mhvtl-bay-monitor -o cat | grep -E 'handle_add|monitoring'
{% endhighlight %}

Le righe di log da qui in avanti abbreviano il nome by-path in `…usb-0:1:1.0-scsi-0:0:0:0`:

{% highlight text %}
mhvtl-bay-monitor: handle_add(): bay …usb-0:1:1.0-scsi-0:0:0:0 not placed: no readable MVTL cartridge in bay
mhvtl-bay-monitor: main(): monitoring 1 bay(s) for raw-disk hot-plug events
{% endhighlight %}

Il disco nel dock è vuoto, quindi per ora non viene piazzato nulla. È normale.

## Configurare PBS {#configure-pbs}

Ora PBS trova il changer e il drive:

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

Crearli:

{% highlight shell %}
proxmox-tape changer create usblib --path /dev/tape/by-id/scsi-USBLIB01
proxmox-tape drive create usbdrive --path /dev/tape/by-id/scsi-00USBDRV01-sg \
    --changer usblib --changer-drivenum 0
{% endhighlight %}

Poi una chiave di cifratura e un media pool che la usi. `key create` chiede una password. Stampa la paper key e conservala lontano da questo server: senza la chiave nessuno può leggere i dischi, te compreso.

{% highlight shell %}
proxmox-tape key create --hint offsite-2026
(umask 077; proxmox-tape key paperkey <fingerprint> --output-format text \
    > /root/offsite-paperkey.txt)
proxmox-tape pool create offsite --allocation always --retention "20 days" \
    --encrypt <fingerprint>
{% endhighlight %}

`--allocation always` avvia un nuovo media set a ogni esecuzione. Finché un'esecuzione sta su un disco, ogni disco è una copia autonoma che può uscire dall'edificio. Se non ci sta, il media set si estende su più dischi, che viaggiano (e si ripristinano) insieme.

La retention deve essere più corta del ciclo di rotazione, altrimenti il disco che torna è ancora protetto e PBS ne chiede uno nuovo. Con tre dischi ruotati settimanalmente, un disco torna dopo 21 giorni, quindi 20 giorni vanno bene.

Nel changer, i mail slot sono numerati dopo gli slot di storage. Con quattro slot, il dock è l'elemento 5:

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

## Inizializzare un disco {#initialize-a-disk}

Si fa una volta per disco e **cancella tutto ciò che c'è sopra**. Formatta il disco nel dock come cartuccia. Il suffisso `L8` nel barcode lo rende un media LTO-8, come il drive, e la capacità è quella del disco:

{% highlight shell %}
mhvtl-raw-format $BAY --barcode USB001L8
{% endhighlight %}

{% highlight text %}
Formatted …usb-0:1:1.0-scsi-0:0:0:0 as raw cartridge 'USB001L8' (partitions: 100, min record 65536 bytes)
{% endhighlight %}

Il monitor se ne accorge da solo e mette la cartuccia nel mail slot:

{% highlight shell %}
journalctl -u mhvtl-bay-monitor -o cat | tail -1
{% endhighlight %}

{% highlight text %}
mhvtl-bay-monitor: handle_add(): placed USB001L8 (library 10 MAP, bay …usb-0:1:1.0-scsi-0:0:0:0)
{% endhighlight %}

PBS tiene in cache lo stato del changer, quindi chiedi una lettura nuova:

{% highlight shell %}
proxmox-tape changer status usblib --cache false
{% endhighlight %}

{% highlight text %}
Unit Attention, Additional sense: Import or export element accessed
│ import-export │        5 │ USB001L8   │             │
{% endhighlight %}

L'"Unit Attention" è la libreria che dice a PBS che qualcuno ha toccato il mail slot. Così si comporta anche una libreria vera.

PBS non etichetta i media che stanno in un mail slot (`changer device does not list any media labels`), quindi spostalo prima in uno slot di storage. Poi `barcode-label` etichetta con il suo barcode ogni cartuccia non etichettata della libreria:

{% highlight shell %}
proxmox-tape changer transfer usblib --from 5 --to 1
proxmox-tape barcode-label --drive usbdrive --pool offsite
{% endhighlight %}

{% highlight text %}
checking/loading media 'USB001L8'
Label media 'USB001L8' for pool 'offsite'
TASK OK
{% endhighlight %}

## Eseguire un backup {#run-a-backup}

`--export-media-set` riporta la cartuccia nel mail slot al termine del job, così il disco è pronto da estrarre non appena il task finisce:

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

Per la routine settimanale, trasformalo in un job:

{% highlight shell %}
proxmox-tape backup-job create weekly-usb --store store1 --pool offsite \
    --drive usbdrive --schedule "sat 02:00" --export-media-set true
{% endhighlight %}

`proxmox-tape backup-job run weekly-usb` lo esegue su richiesta.

Il disco è davvero cifrato? Ho cercato in tutti i 16 GB del dispositivo raw quattro campioni da 32 byte di un file casuale di quel backup. Ogni campione è comparso una volta nel datastore PBS e da nessuna parte sul disco.

## Estrarre il disco {#pull-the-disk}

Controlla che la cartuccia sia nel mail slot, poi scollega il disco:

{% highlight shell %}
proxmox-tape changer status usblib --cache false | grep import-export
{% endhighlight %}

{% highlight text %}
│ import-export │        5 │ USB001L8   │             │
{% endhighlight %}

Il monitor toglie la cartuccia dalla libreria:

{% highlight shell %}
journalctl -u mhvtl-bay-monitor -o cat | tail -1
{% endhighlight %}

{% highlight text %}
mhvtl-bay-monitor: handle_remove(): removed USB001L8 (library 10 MAP, bay …usb-0:1:1.0-scsi-0:0:0:0)
{% endhighlight %}

PBS tiene il disco nel suo inventario come media offline, con il suo catalogo:

{% highlight shell %}
proxmox-tape media list
{% endhighlight %}

{% highlight text %}
│ label-text │ pool    │ media-set-name           │ seq-nr │ status │ location │ catalog │
│ USB001L8   │ offsite │ Fri Nov 13 13:09:32 2026 │      0 │ full   │ offline  │      ok │
{% endhighlight %}

Se un backup è stato eseguito senza `--export-media-set`, fai tu l'export prima di estrarre il disco:

{% highlight shell %}
proxmox-tape unload --drive usbdrive
proxmox-tape export-media --drive usbdrive USB001L8
{% endhighlight %}

## La routine settimanale {#the-weekly-routine}

Una volta inizializzati i dischi, una rotazione è:

1. Collega il disco che è il suo turno. Compare nel mail slot 5.
2. `proxmox-tape changer transfer usblib --from 5 --to 1`
3. Lascia girare il job. Esporta il disco di nuovo nello slot 5.
4. Scollegalo e portalo fuori sede.

Un disco scaduto viene riutilizzato automaticamente dal pool. `mhvtl-raw-format` e `barcode-label` servono solo per i dischi nuovi. Nell'ambiente di test, un secondo disco (`USB002L8`) ha seguito gli stessi passi, e il job ha scritto su di esso da solo.

## Restore {#restore}

Ricollega il disco, spostalo in uno slot di storage e ripristina il suo media set in un datastore. `proxmox-tape media list` mostra l'UUID del media set:

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

La chiave è nel key store di PBS, quindi il restore non ha chiesto nulla. Il file casuale da 2 GiB in quello snapshot è tornato con lo stesso SHA-256 dell'originale.

Il restore lascia il disco nel drive. Rimandalo nel mail slot prima di scollegarlo:

{% highlight shell %}
proxmox-tape unload --drive usbdrive
proxmox-tape export-media --drive usbdrive USB001L8
{% endhighlight %}

Su un PBS ricostruito, il key store e il catalogo dei media non ci sono più. Configura di nuovo mhVTL e il changer e il drive di PBS come sopra, ma **non formattare né etichettare i dischi**. Collega il disco, spostalo in uno slot, poi recupera la chiave dalla copia cartacea e lascia che PBS legga il disco:

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

Poi ripristina il media set come sopra. L'ho provato cancellando chiave, pool, inventario e cataloghi sul PBS di test: il restore in un nuovo datastore ha funzionato e il checksum coincideva.

## Avvertenze {#caveats}

- **Non estrarre un disco caricato.** Ci ho provato: mentre il disco era fuori, il drive ha riportato "Medium format corrupted". Dopo averlo ricollegato, `proxmox-tape unload` seguito da `proxmox-tape load-media USB001L8 --drive usbdrive` l'ha rimesso a posto, e una scansione completa del catalogo ha letto i dati senza problemi. Comunque, aspetta il mail slot.
- **Bridge USB e flush.** mhVTL chiede un flush a ogni filemark e a ogni unload, ma alcuni bridge USB-SATA economici ignorano i flush della cache. Compra un dock UAS decente.
- **Più dock.** Un secondo dock è un'altra riga in `mhvtl_raw_bays.conf` (poi riavvia `mhvtl-bay-monitor`). Ogni disco finisce nel primo mail slot libero, non necessariamente quello della sua riga, quindi controlla il barcode con `changer status --cache false` prima di spostare o estrarre qualsiasi cosa. Estrarre un disco toglie solo la sua cartuccia.
- **La cifratura richiede questo snapshot o uno più recente.** Nelle build di mhVTL precedenti alla [#328](https://github.com/markh794/mhvtl/pull/328), la cifratura del drive è simulata e la chiave viene scritta accanto ai dati. Controlla `man device.conf` per l'opzione `Encryption:`. Se non c'è, usa invece la [cifratura lato client di PBS](https://pbs.proxmox.com/docs/backup-client.html#encryption).
- **Codice nuovo.** Le cartucce su disco raw sono giovani. Prova un restore prima di farci affidamento, come con qualsiasi backup.

---

{% include series-nav.html %}
