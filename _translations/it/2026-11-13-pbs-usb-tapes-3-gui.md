---
title: "Dischi USB come nastri per Proxmox Backup Server (3/3): punta e clicca"
description: "La stessa configurazione della parte 2, dalla dashboard di mhVTL Control e dall'interfaccia web di PBS. Restano poche righe di shell; tutto il resto sono clic."
date: 2026-11-13 10:02:00 -0300
permalink: /it/datacenter/2026/11/13/pbs-usb-tapes-3-gui.html
lang: it
categories:
  - storage-backup
tags:
  - proxmox
  - pbs
  - tape
  - mhvtl
series: pbs-usb-tapes
series_part: 3
series_title: "Punta e clicca"
---

La [parte 2](/it/datacenter/2026/11/13/pbs-usb-tapes-2-cli.html) ha costruito la configurazione dalla shell. Questa parte lo fa con il mouse: [mhVTL Control](https://github.com/ciroiriarte/mhvtl-control) per la libreria virtuale, e l'interfaccia web di PBS per il lato nastri. Se non hai letto la [parte 1](/it/datacenter/2026/11/13/pbs-usb-tapes-1-why.html), lì si spiega perché vorresti dei job su nastro di PBS su dischi USB.

Non tutto ha ancora un pulsante: installare i pacchetti, abilitare le scritture della dashboard e associare il dock richiedono ancora poche righe di shell.

<!--more-->

{% include series-nav.html %}

La configurazione è la stessa di prima: PBS 4.2 con un datastore chiamato `store1`, un dock USB e dischi da ruotare. L'ambiente di test era una VM Debian 13 appena installata con mhVTL `1.8.0+git20261101.7e3a101` e mhVTL Control 0.6.0, entrambi dal mio [progetto su OBS](https://build.opensuse.org/project/show/home:ciriarte:mhvtl).

## La parte di shell {#the-shell-part}

Aggiungi il repository, installa entrambi i pacchetti e tieni fuori il driver `ch` del kernel. Perde riferimenti ai drive ogni volta che compare un changer, e PBS non ne ha bisogno (la [parte 2](/it/datacenter/2026/11/13/pbs-usb-tapes-2-cli.html#install-mhvtl) ha i dettagli):

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

Il modulo del kernel viene compilato con DKMS per il kernel in esecuzione. Se hai appena aggiornato il kernel, riavvia prima.

La dashboard è di sola lettura di default. Per le modifiche servono un token API e un piccolo helper privilegiato che applica i cambiamenti:

{% highlight shell %}
TOKEN=$(openssl rand -hex 24); echo "$TOKEN"
echo "MHVTL_CONTROL_API_TOKEN=$TOKEN" >> /etc/mhvtl-control/mhvtl-control.env
chmod 600 /etc/mhvtl-control/mhvtl-control.env
systemctl enable --now mhvtl-control-apply.socket
systemctl enable mhvtl-control-apply-recover.service
systemctl enable --now mhvtl-control mhvtl.target
{% endhighlight %}

mhVTL Control è in ascolto su `127.0.0.1:8080`, quindi raggiungilo con un tunnel SSH dalla tua workstation:

{% highlight shell %}
ssh -L 8080:127.0.0.1:8080 root@pbs.example.com
{% endhighlight %}

Apri <http://localhost:8080>, clicca su **Target…** e incolla il token.

## Creare la libreria {#create-the-library}

Il pacchetto include due librerie STK di esempio. PBS non le vede: gli serve un changer che riporti la pagina VPD 0x83 di INQUIRY, e i modelli STK emulati da mhVTL non lo fanno. Quindi aggiungiamo una libreria con personalità IBM.

In **Configuration**, clicca su **New library…**:

- **Model:** IBM 03584. La procedura guidata nota che "reports VPD page 83h", ed è proprio quello che ci serve.
- **ID** 20, **serial** `MHV0020`, **4** slot di storage, **2** slot MAP (mail).
- **Un drive:** IBM ULT3580-TD8, ID 21, serial `MHV002001`.
- **For:** Proxmox Backup Server. Attiva un controllo di ciò che serve a PBS.

{% include image.html url="/assets/img/2026-11-13-pbs-usb-m01-new-library.jpg" description="mhVTL Control: procedura guidata New library, IBM 03584 con PBS selezionato" width=1512 height=806 %}

Clicca su **Stage library**, poi su **Check**. Check è una prova a vuoto: valida la nuova configurazione ed elenca cosa verrebbe riavviato dall'apply. Qui sono solo i due nuovi daemon, e il controllo PBS passa:

{% include image.html url="/assets/img/2026-11-13-pbs-usb-m02-check-pbs.jpg" description="Check: la libreria 20 soddisfa i requisiti di PBS, si riavviano solo vtllibrary@20 e vtltape@21" width=1512 height=806 %}

Clicca su **Apply**. La libreria è attiva in pochi secondi.

La procedura guidata lascia la compressione del drive disattivata, il che va bene: i chunk di PBS sono già compressi. Le librerie di esempio restano dove sono (vedi [Spigoli da limare](#rough-edges)), quindi i loro drive compariranno più avanti nell'elenco dei drive di PBS.

## Associare il dock {#bind-the-dock}

Questo è ancora un passaggio da shell. Collega un disco al dock, trova il nome stabile della porta in `/dev/disk/by-path` (quello con `usb-`, non `usbv3-`) e associalo alla libreria 20. La seconda colonna è lo slot mail previsto; per ora la cartuccia finisce nel primo libero:

{% highlight shell %}
ls -l /dev/disk/by-path/ | grep -- -usb-
BAY=/dev/disk/by-path/pci-0000:00:01.0-usb-0:1:1.0-scsi-0:0:0:0
echo "20  1  $BAY" > /etc/mhvtl/mhvtl_raw_bays.conf
systemctl enable --now mhvtl-bay-monitor
{% endhighlight %}

Il disco è vuoto, quindi il monitor registra "not placed" e aspetta.

## Formattare il disco {#format-the-disk}

In **Raw Disk Dock**, il disco appare come "NO MVTL (UNFORMATTED)". Clicca su **Format…**, scrivi il nome del dispositivo per confermare (questo **cancella il disco**) e dagli un barcode. Il suffisso `L8` lo rende un supporto LTO-8, coerente con il drive:

{% include image.html url="/assets/img/2026-11-13-pbs-usb-m03-format.jpg" description="Raw Disk Dock: formattare il disco come cartuccia USB001L8" width=1512 height=806 %}

Il bay monitor rileva subito la nuova cartuccia, e il **Library Rack** la mostra in MAP 1. Il pannello del drive mostra anche `encryption aes-gcm`: quando PBS imposta una chiave, mhVTL cifra ogni blocco con AES-256-GCM.

{% include image.html url="/assets/img/2026-11-13-pbs-usb-m04-rack-map.jpg" description="Library Rack: USB001L8 nello slot mail" width=1512 height=806 %}

Passa all'interfaccia web di PBS, su `https://<pbs>:8007`.

## Aggiungere il changer e il drive {#add-the-changer-and-the-drive}

**Tape Backup → Changers → Add**. Il menu a tendina dei percorsi elenca solo il changer IBM (`scsi-MHV0020`). Gli esempi STK sono invisibili a PBS, come previsto. L'ho chiamato `usblib` e ho lasciato vuoto Import-Export Slots, dato che PBS li legge dal changer.

{% include image.html url="/assets/img/2026-11-13-pbs-usb-p01-add-changer.jpg" description="PBS: aggiungere il changer" width=1512 height=806 %}

**Drives → Add**: nome `usbdrive`, changer `usblib`, numero di drive 0. L'elenco dei percorsi mostra tutti i drive mhVTL, compresi quelli di esempio, quindi scegli quello con serial `0MHV002001`:

{% include image.html url="/assets/img/2026-11-13-pbs-usb-p02-add-drive.jpg" description="PBS: aggiungere il drive, scelto per serial" width=1512 height=806 %}

## Chiave di cifratura e media pool {#encryption-key-and-media-pool}

**Encryption Keys → Add**: un suggerimento e una password. PBS offre poi una chiave su carta. Stampala e tienila lontano da questo server: senza la chiave, i dischi sono solo rumore.

{% include image.html url="/assets/img/2026-11-13-pbs-usb-p03-add-key.jpg" description="PBS: aggiungere una chiave di cifratura dei nastri" width=1512 height=806 %}

**Media Pools → Add**:

- **Name:** offsite
- **Allocation:** always. Ogni esecuzione inizia un nuovo media set. Finché un'esecuzione sta su un disco, ogni disco è una copia autonoma che può uscire dall'edificio.
- **Retention:** 20 giorni. Deve essere più breve del ciclo di rotazione: tre dischi ruotati settimanalmente tornano dopo 21 giorni.
- **Encryption key:** quella appena creata.

{% include image.html url="/assets/img/2026-11-13-pbs-usb-p04-add-pool.jpg" description="PBS: media pool offsite" width=1512 height=806 %}

## Etichettare il disco {#label-the-disk}

Apri il changer (**usblib** nell'albero a sinistra). Il disco è nello slot I/E 5, "Not Labeled". Gli slot mail sono numerati dopo i quattro slot di storage. PBS non etichetta i supporti in uno slot mail, quindi clicca su **Import** e spostalo nello slot 1, poi **Barcode Label** con il pool `offsite`.

{% include image.html url="/assets/img/2026-11-13-pbs-usb-p05-changer-ie.jpg" description="Vista del changer in PBS: il nuovo disco nello slot I/E 5" width=1512 height=806 %}

## Fare il backup {#back-up}

**Content → New Backup**: datastore `store1`, pool `offsite`, drive `usbdrive`, e spunta **Export Media-Set**. Questo riporta la cartuccia nello slot mail quando il job finisce, pronta da scollegare.

{% include image.html url="/assets/img/2026-11-13-pbs-usb-p06-new-backup.jpg" description="PBS: nuovo backup su nastro con Export Media-Set" width=1512 height=806 %}

{% include image.html url="/assets/img/2026-11-13-pbs-usb-p07-backup-log.jpg" description="Log del task: 2148 MB scritti, supporto esportato nello slot I/E 5" width=1512 height=806 %}

Per la routine settimanale, aggiungi un job in **Backup Jobs → Add**: stesso datastore, pool e drive, pianificazione `sat 02:00`, con Export Media-Set spuntato.

{% include image.html url="/assets/img/2026-11-13-pbs-usb-p11-backup-job.jpg" description="PBS: job settimanale di backup su nastro" width=1512 height=806 %}

## Togliere il disco {#pull-the-disk}

Quando il log del task dice che il supporto è stato esportato, scollega il disco. Il bay monitor toglie la cartuccia dalla libreria. PBS tiene in cache ciò che sa, quindi clicca su **Reload** in **Inventory**: il disco risulta offline, con il suo catalogo.

{% include image.html url="/assets/img/2026-11-13-pbs-usb-p08-inventory-offline.jpg" description="Inventario di PBS: USB001L8 offline, catalogo conservato" width=1512 height=806 %}

Anche la vista del changer continua a mostrare la cartuccia finché non clicchi su **Reload** lì.

La settimana prossima: collega il disco che tocca, fai **Import** in uno slot di storage e lascia girare il job. Un disco scaduto viene riutilizzato automaticamente. Formattare ed etichettare serve solo per i dischi nuovi.

## Ripristino {#restore}

Ricollega il disco. Quando è nello slot mail, fai **Reload** del changer e **Import** in uno slot. Poi in **Content**, clicca sull'icona di ripristino accanto al media set, scegli gli snapshot e seleziona un drive e un datastore di destinazione:

{% include image.html url="/assets/img/2026-11-13-pbs-usb-p09-restore-target.jpg" description="Procedura guidata di ripristino di PBS: drive e datastore di destinazione" width=1512 height=806 %}

{% include image.html url="/assets/img/2026-11-13-pbs-usb-p10-restore-log.jpg" description="Log del ripristino: il media set era cifrato con la chiave del pool" width=1512 height=806 %}

Il log mostra l'impronta della chiave con cui era cifrato il media set, e il ripristino ha riportato 2,148 GB nel datastore. Il file casuale da 2 GiB in quello snapshot è tornato con lo stesso SHA-256 dell'originale.

Il ripristino lascia il disco nel drive. Prima di scollegarlo, rimandalo nello slot mail dalla vista del changer. Clicca su **Unload** nelle azioni del drive, che rimette la cartuccia nello slot 1. Poi clicca su **Transfer** sullo slot 1 e scegli lo slot I/E 5. (L'icona accanto a Transfer è **Format**. Non confonderle.)

{% include image.html url="/assets/img/2026-11-13-pbs-usb-p12-transfer-to-ie.jpg" description="Vista del changer: USB001L8 di nuovo nello slot I/E 5, pronto da scollegare" width=1456 height=818 %}

Ripristinare su un PBS ricostruito richiede qualche passaggio in più, a partire dal recupero della chiave dalla copia cartacea. La [parte 2](/it/datacenter/2026/11/13/pbs-usb-tapes-2-cli.html#restore) ha i comandi, tutti eseguiti in un ambiente di test.

## Spigoli da limare {#rough-edges}

mhVTL Control 0.6.0 è giovane, e questa prova ha fatto emergere alcune cose che sistemerò:

- Le librerie di esempio che contengono cartucce non si possono eliminare dalla dashboard: la cancellazione fallisce il proprio controllo. Non danno fastidio, a parte un elenco di drive più lungo in PBS.
- Il pannello dei media mostra un errore "Maximum call stack size exceeded".
- Raw Disk Dock offre **Format…** per il lettore CD-ROM, e nomina i dischi per `sdX` invece che per bay.

Nessuna ha intralciato la procedura. Le avvertenze della [parte 2](/it/datacenter/2026/11/13/pbs-usb-tapes-2-cli.html#caveats) valgono anche qui: aspetta lo slot mail prima di togliere un disco, usa un dock che rispetti i flush della cache e prova un ripristino prima di farci affidamento.

---

{% include series-nav.html %}
