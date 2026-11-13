---
title: "Eseguire SCO Openserver 5.0.7 in VirtualBox"
description: "Guida tecnica per virtualizzare SCO OpenServer 5.0.7 su VirtualBox, con configurazione della VM, procedura di installazione, configurazione di rete e un workaround per il Guru Meditation."
date: 2009-10-08 16:38:22 -0400
permalink: /it/index.php/2009/10/08/running-sco-openserver-5-0-7-in-virtualbox/
lang: it
categories:
  - virtualization
tags:
  - virtualbox
  - sco
---

**Aggiornamento:** *A partire da VirtualBox 3.0.10, Openserver 5.0.7 non dovrebbe richiedere workaround per l'installazione, manca solo il supporto SCSI… (controlla i bug report elencati).*

Un cliente doveva sostituire un vecchio server SCO<!--more--> che eseguiva Foxplus; dato che è improbabile che Openserver 5 giri su hardware nuovo, l'unica strada disponibile in questo caso era virtualizzare il server Openserver. Ad oggi iBCS o ABI o comunque si chiami l'ultima incarnazione, per noi non ha funzionato.

Usiamo SLES10SP2@x86\_64 come host, ma qualsiasi host che esegua VirtualBox dovrebbe andare bene. L'installazione originale è stata fatta con la 3.0.4, ma questi passaggi sono stati testati con la 3.0.8 per questo articolo. L'unica funzionalità mancante è la GUI.

**Configurazione della VM**

*General*

- Operating System: Other
- Version: Other

*System*

- Base Memory: 512M
- Enable ACPI
- Processor: 1
- Enable VT-x/AMD-V
- Enable Nested Paging (ha mostrato miglioramenti nei test di creazione dei file)

*Hard Disks*

- IDE Controller: 1 disco (6GB, dinamico). Nessuno dei driver SCSI ufficiali rileva gli adattatori SCSI virtualizzati di VirtualBox

*CD/DVD Drive*

- Image mounted: OpenServer-5.0.7Hw-10Jun05\_1800.iso

*Network*:

- Intel PRO/1000 MT Desktop

**Procedura di installazione** (elencherò solo le modifiche rilevanti in ogni passaggio)

- *Preparing your disk and choosing software* -> *Optional Software*: In "Graphical Environment" dobbiamo deselezionare "X Server and Graphics Drivers", perché Video Configuration Manager causa "Guru Meditation".

- *Configuring optional software* -> *Network card*: Rimandata (non funzionerà prima di installare MP5)

**Post installazione**

*Installare MP5*

- Monta osr507suppcd5.iso. Esegui "custom" e seleziona "Software" -> "Install New" -> "From <your_vm_name>" -> "Media Device" = CD-ROM Drive 0

Seleziona e installa**:**

- SCO Openserver Release 5.0.7 Maintenance Pack 5
- SCO Openserver Release 5.0.7 Graphics and NIC Drivers

Riavvia

*Configurazione di rete*

- Esegui scoadmin –&gt; Networks –&gt; Network Configuration Manager –&gt; Hardware –&gt; Add new LAN Adapter. Dovrebbe rilevare la NIC Intel.

**Risolvere il Guru Meditation allo spegnimento**

Anche gli eventi di arresto per riavviare o spegnere scatenano “Guru Meditation”. Per ora ho trovato un workaround per lo spegnimento, ma il riavvio è ancora rotto.

Modifica /etc/conf/pack.d/uapm/space.c, cerca la funzione "uapm_offstates" di tipo "ulong_t" e modifica gli eventi 0 e 3 in modo che scatenino "APMPWR_OFF".

Ecco una patch:

```diff
--- space.c.orig 2009-10-08 16:38:00.000000000 -0400
+++ space.c 2009-10-08 16:38:00.000000000 -0400
@@ -76,10 +76,10 @@
 */

 ulong_t uapm_offstates[] = {
-  APMPWR_READY, /* 0 AD_HALT No auto reboot */
+  APMPWR_OFF, /* 0 AD_HALT No auto reboot */
   APMPWR_READY, /* 1 AD_BOOT Auto reboot */
   APMPWR_READY, /* 2 AD_IBOOT (same as AD_BOOT) */
-  APMPWR_SUSPEND, /* 3 AD_PWRDOWN Turn off power */
+  APMPWR_OFF, /* 3 AD_PWRDOWN Turn off power */
   APMPWR_STANDBY, /* 4 AD_PWRNAP Turn off if no A/C */
   APMPWR_SUSPEND, /* (anything else) (essentially AD_HALT) */
 };
```

Ricollega il kernel e riavvia:

> cd /etc/conf/cf.d  
> ./link\_unix

**Bug report pendenti**:

- http://www.virtualbox.org/ticket/3953
- http://www.virtualbox.org/ticket/5096
- http://www.virtualbox.org/ticket/5164

È tutto, spero che i ragazzi di Sun riescano a sistemare questi problemi nelle prossime versioni…
