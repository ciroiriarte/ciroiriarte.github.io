---
title: "Dischi USB come nastri per Proxmox Backup Server (1/3): perché, e cosa c'è di nuovo"
description: "Perché potresti volere i tape job di PBS su semplici dischi USB, cosa ha aggiunto mhVTL per renderlo possibile (cartucce su disco raw, baie hot-plug, vera cifratura nel drive) e dove sta andando."
date: 2026-11-13 10:00:00 -0300
permalink: /it/datacenter/2026/11/13/pbs-usb-tapes-1-why.html
lang: it
categories:
  - storage-backup
tags:
  - proxmox
  - pbs
  - tape
  - mhvtl
series: pbs-usb-tapes
series_part: 1
series_title: "Perché, e cosa c'è di nuovo"
---

Un datastore di Proxmox Backup Server è storage online. È veloce, deduplicato e sempre online. Questo è il problema: chiunque ottenga root sull'host PBS, o un token con privilegi sufficienti, può raggiungerlo. La copia che deve sopravvivere a un ransomware, a un `rm` digitato con le dita grosse o a un incendio dovrebbe stare su uno scaffale, scollegata, idealmente in un altro edificio.

La risposta classica è il nastro, e PBS ha un ottimo supporto per i nastri. Ma un drive LTO costa più di quanto molti piccoli siti spendano per l'intero server di backup. Una manciata di dischi USB costa quasi niente, e qualcuno può portarseli a casa il venerdì.

Quindi l'idea di questa serie è semplice: **far comportare i dischi USB come nastri**, e lasciare che PBS faccia con i nastri quello che già sa fare bene.

<!--more-->

Questa è la parte 1 di una serie di tre:

1. **Perché, e cosa c'è di nuovo** (questo post): il ragionamento, e cosa c'è di nuovo in mhVTL per renderlo possibile.
2. [La procedura da CLI](/it/datacenter/2026/11/13/pbs-usb-tapes-2-cli.html): mhVTL e PBS dalla shell, da copiare e incollare.
3. [La procedura point & click](/it/datacenter/2026/11/13/pbs-usb-tapes-3-gui.html): la stessa cosa, dalla dashboard di mhVTL Control e dalla web UI di PBS.

## Cosa offre già PBS {#what-pbs-already-offers}

Prima di costruire qualsiasi cosa, vale la pena controllare cosa offre già PBS.

**I client non scrivono mai direttamente su nastro.** PVE e `proxmox-backup-client` fanno sempre il backup su un datastore. Poi un backup job su nastro copia gli snapshot dal datastore in un *media pool* ([documentazione PBS, Tape Backup](https://pbs.proxmox.com/docs/tape-backup.html)). Questo si adatta al piano: il datastore resta la prima copia veloce, e i dischi diventano la seconda copia, offline.

Per portare fuori una copia dal datastore, PBS ha tre opzioni:

- I **sync job** copiano gli snapshot tra datastore, in locale o verso un PBS remoto (pull, e push da PBS 3.3).
- I **removable datastore** (da [PBS 3.3](https://www.proxmox.com/en/about/company-details/press-releases/proxmox-backup-server-3-3)) mettono un intero datastore su un disco USB formattato con ext4 o XFS. Lo colleghi, sincronizzi al suo interno e lo smonti ([documentazione PBS, Removable Datastores](https://pbs.proxmox.com/docs/storage.html)).
- I **tape backup job** scrivono gli snapshot in *media set*, con politiche di allocazione e retention, un catalogo di cosa c'è su ogni nastro, e cifratura nel drive.

Per uno o due dischi, un removable datastore è più semplice, e probabilmente la risposta migliore. La semantica dei nastri comincia a ripagare quando ruoti più dischi e vuoi che PBS ne tenga traccia:

| | Removable datastore | Tape job su un disco raw mhVTL |
|---|---|---|
| Software aggiuntivo | Nessuno | mhVTL (modulo del kernel e daemon) |
| Formato su disco | ext4/XFS con un chunk store | Nessun filesystem, un'immagine sequenziale di nastro |
| Copia | Incrementale: un sync copia solo i chunk nuovi | Copia completa per media set (con `--allocation always`) |
| Più grande di un disco | No | Un media set può estendersi su più dischi |
| Estrazione del disco | Smontaggio pulito, oppure il datastore resta in modalità manutenzione | Cartuccia esportata nel mail slot, dati già scritti su disco |
| Rotazione di N dischi | A mano | Media pool con politiche di allocazione e retention |
| Cosa c'è sul disco nel cassetto? | Collegalo e guarda | PBS tiene un catalogo dei media offline |
| Cifratura | Lato client | Lato client, oppure la chiave del pool ([AES-256-GCM nel drive](#real-encryption)) |
| Restore | Sfogli e ripristini direttamente | Prima si ripristina il media set in un datastore |
| Altro software di backup | Solo PBS | Qualsiasi cosa parli con una tape library |
| Passare a un vero LTO in futuro | Si riparte da zero | Stessi pool e job, si cambia l'hardware |

Due piccoli bonus per il disco raw: nessun componente desktop prova a montarlo automaticamente, e un disco estratto al momento sbagliato non ha un filesystem su cui fare `fsck`.

## Cosa è cambiato in mhVTL {#what-changed-in-mhvtl}

[mhVTL](https://github.com/markh794/mhvtl) è una virtual tape library per Linux. Emula drive a nastro SCSI e changer robotici abbastanza bene da far sì che le applicazioni di backup non vedano la differenza. Tradizionalmente, ogni cartuccia virtuale è una directory di file sotto `/opt/mhvtl`. Va bene per i test, ma una cartuccia rinchiusa in un filesystem sul server di backup non serve a nessuno quando l'edificio va a fuoco.

Nelle ultime settimane è arrivato upstream un insieme di modifiche che permette alle cartucce di vivere su dischi removibili. Le ho scritte io; Mark Harvey, il maintainer di mhVTL, le ha riviste e integrate.

### Cartucce su disco raw {#raw-disk-cartridges}

Ora un intero block device può essere una cartuccia ([#214](https://github.com/markh794/mhvtl/pull/214)). Un disco è un nastro. Niente tabella delle partizioni e niente filesystem.

Il primo megabyte viene lasciato vuoto, così nulla sull'host pensa che il disco valga la pena di essere montato. Dopo vengono un superblocco (più una copia speculare) con il codice a barre e il layout, la memoria della cartuccia (MAM) e il flusso dei dati.

`mhvtl-raw-format` inizializza un disco e, da [#293](https://github.com/markh794/mhvtl/pull/293), scrive anche una MAM corretta, così il drive conosce la capacità fin dalla prima scrittura.

Quando un'applicazione di backup scrive un filemark o scarica il nastro, mhVTL fa il flush del disco (`fdatasync`) prima di rispondere. In un ambiente di test, i dischi tolti dal mail slot e ricollegati sono stati riletti intatti ogni volta.

### Baie hot-plug {#hot-plug-bays}

`mhvtl-bay-monitor` controlla udev e associa una porta USB fisica (il suo nome stabile in `/dev/disk/by-path`, mai `/dev/sdX`) ai mail slot di una library. I mail slot sono la stazione di import/export di una library: mhVTL li chiama MAP, PBS li chiama slot I/E.

Colleghi un disco formattato al dock e la sua cartuccia compare in un mail slot. Lo estrai e la cartuccia sparisce dalla library. Alcune modifiche successive gestiscono i casi limite:

- un disco formattato sul posto ([#294](https://github.com/markh794/mhvtl/pull/294))
- un monitor riavviato con un disco nel dock ([#296](https://github.com/markh794/mhvtl/pull/296))
- più dock su una stessa library ([#298](https://github.com/markh794/mhvtl/pull/298))

Per PBS è esattamente come se un operatore si avvicinasse a una library vera e infilasse un nastro nel mail slot.

### Vera cifratura {#real-encryption}

Fino a poco tempo fa, la cifratura del drive in mhVTL era *simulata*. Il drive accettava la chiave e scriveva i dati in chiaro, con la chiave nell'header di ogni blocco. Va bene per testare un'applicazione, ma è inutile per dischi che escono dall'edificio.

Da [#328](https://github.com/markh794/mhvtl/pull/328), il drive cifra ogni blocco con AES-256-GCM. La chiave è derivata da ciò che invia l'applicazione più un salt casuale memorizzato nella memoria della cartuccia, e non viene mai scritta sul disco.

È il comportamento predefinito per i drive che supportano la cifratura, quindi un media pool di PBS con una chiave di cifratura ora ti dà un disco cifrato. In un ambiente di test ho cercato nel disco raw dei campioni di un file casuale di cui avevo fatto il backup: erano tutti nel datastore PBS, e nessuno sul disco cifrato.

### Compressione più veloce {#faster-compression}

LZ4 e Zstandard si sono aggiunti ai vecchi zlib e LZO. Non conta molto per PBS, i cui chunk sono già compressi, e mhVTL memorizza un blocco così com'è quando la compressione non lo riduce.

### Una dashboard {#a-dashboard}

[mhVTL Control](https://github.com/ciroiriarte/mhvtl-control) è un mio progetto separato: una API REST e una dashboard web per mhVTL. Mostra le library in tempo reale, modifica la configurazione con un passaggio di verifica prima di applicarla, e formatta i dischi raw. La parte 3 lo usa per la versione point & click.

## Dove sta andando tutto questo {#where-this-is-going}

In questa serie, il dock USB è collegato all'host PBS stesso. Il passo successivo è spostare i dischi su una macchina separata.

mhVTL ora può esportare le sue library via **iSCSI**: `mhvtl-fabrics` ([#337](https://github.com/markh794/mhvtl/pull/337)) predispone i target sopra il backend TCMU, che è ancora sperimentale. Anche il supporto come target **Fibre Channel** è in lavorazione. Con l'uno o l'altro, una macchina separata con baie hot-swap diventa "la tape library", e l'host PBS vede una normale tape library sulla fabric. Niente mhVTL sul server di backup, niente cavo USB verso di esso, e i dischi ruotati sulla macchina che li ospita.

Merita un post tutto suo quando sarà passato da un ambiente di test. Per ora, la [parte 2](/it/datacenter/2026/11/13/pbs-usb-tapes-2-cli.html) costruisce la versione locale dalla shell.

---

{% include series-nav.html %}
