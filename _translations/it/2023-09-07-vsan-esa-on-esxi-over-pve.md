---
title: "vSAN ESA su ESXi sopra PVE"
description: "Cluster vSAN ESA annidato a scopo di test"
date: 2023-09-07 00:00:00 -0400
permalink: /it/homelab/2023/09/07/vsan-esa-on-esxi-over-pve.html
lang: it
categories:
  - virtualization
  - storage-backup
tags:
  - proxmox
  - esxi
  - vsan
  - nested-virtualization
---

## Un po' di contesto {#a-little-bit-of-context}

### vSAN OSA {#vsan-osa}
Uno dei miei maggiori grattacapi come cliente riguardo all'offerta SDDC di VMware è vSAN OSA. La prima volta che l'ho visto in azione, mi è sembrato una risposta "anche io" a [Nutanix](https://www.nutanix.com/mx/info/software-defined-storage), che abbiamo introdotto con successo, credo come primo cliente in Paraguay, intorno al 2016 (se la memoria non mi inganna). 

Inoltre, venendo da un background di soluzioni basate su FibreChannel come [vMAX di EMC](https://www.youtube.com/watch?v=Zp3yMGlzZhM) e [VSP di Hitachi](https://knowledge.hitachivantara.com/Documents/Storage/VSP_G1X00_and_VSP_F1500/80-06-6x/Hardware_Guide/03_Hardware_architecture), era davvero difficile da vendere in termini di funzionalità (niente snapshot, niente tiering, niente replica, ecc.) e passare a cluster da 20 nodi solo perché ci serviva capacità per grossi database Oracle non aveva senso (non conviene)

Un altro modo di vederla: se confronti vSAN OSA su vSphere con altre soluzioni che servono Xen o KVM, manca di flessibilità:
- un solo pool per cluster
- un solo tipo di disco
- il disco di cache come punto di guasto importante

Quando non c'era ESXi all'orizzonte, sceglievamo semplicemente un'altra alternativa come [CEPH](https://docs.ceph.com/en/latest/architecture/) o [MooseFS](https://moosefs.com/blog/architecture/) (no [GlusterFS](https://docs.gluster.org/en/main/Quick-Start-Guide/Architecture/), non ti vuole nessuno....)

Il lato positivo è che è un punto di ingresso interessante verso alternative migliori per chi è tecnologicamente indietro: pensa a iSCSI su 1GbE o CIFS/SMB3 servito dal tuo file server Windows Server :s

Tutto sommato ha senso se:
- sei un'azienda VMware con team infrastruttura molto ridotti
- vuoi un modo rapido per introdurre una piattaforma di virtualizzazione
- non c'è uno Storage + SAN centralizzato di partenza
- le tue esigenze di storage non sono sproporzionate rispetto al compute
- non ti servono servizi storage avanzati come fare snapshot dei dischi del tuo database Oracle di produzione da 40TB in linea (10*4TB + ASM) per presentarli a un'istanza secondaria di reporting.

### vSAN ESA {#vsan-esa}
La prima volta che ho sentito parlare di [vSAN ESA](https://core.vmware.com/blog/introduction-vsan-express-storage-architecture) è stato al VMware Explore 2022. Non è perfetto, ma è un passo nella direzione giusta.

Giusto per essere chiari, sono abbastanza contento dell'evoluzione. :)

Assicurati di guardare la registrazione on demand della sessione VMware Explore 2022 [Get to Know the Next-Generation of vSAN Architecture](https://www.vmware.com/explore/video-library/video-landing.html?sessionid=1663909090011001QAvr&videoId=6315818080112) per capire tutte le novità.

## Tornando al nostro ambiente annidato su Proxmox. {#going-back-to-our-proxmox-nested-environment}

Con questo contesto, ti consiglio davvero di esplorare i cambiamenti della nuova architettura.

Se vuoi sporcarti le mani, vSAN ESA può essere distribuito nel nostro ambiente annidato ESX-on-KVM/Proxmox. 

Ovviamente:
- non sarà supportato, ma ti permetterà di giocarci
- i veri test di prestazioni richiederanno un setup fisico adeguatamente supportato

Ci saranno dei warning, perché non rispettiamo nessuna [configurazione supportata](https://kb.vmware.com/s/article/90343), in particolare:
- interfacce 25GbE
- controller NVMe
- 512GB di RAM per nodo

### Controller dei dischi {#disk-controller}

In un mondo ideale dovremmo usare un controller NVMe, che QEMU supporta, ma [Proxmox non supporta ancora](https://bugzilla.proxmox.com/show_bug.cgi?id=2255). Stando così le cose, usiamo il controller SATA predefinito.

### Provisioning dei dischi {#provisioning-of-the-disks}

Per questo test prenderemo 3 istanze ESXi annidate e aggiungeremo a ciascuna 3 dischi da 100GB che emulano SSD. Puoi usare più dischi e/o più grandi, il cielo (il tuo portafoglio?) è il limite.

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

## Configurazione di vSAN {#vsan-setup}

Puoi configurare il cluster vSAN come faresti normalmente, durante il deployment di vCenter o dopo averlo messo in funzione.

Il primo warning che vedrai è che le NIC non sono supportate (sono richieste 25GbE). Puoi andare avanti comunque.

{% include image.html url="/assets/img/2023-09-07-nic-speed-warning.png" description="Immagine 1 - Warning sulla NIC" alt="Warning sulla NIC" width=1365 height=907 %}

Se vai avanti, i dischi saranno marcati come incompatibili. Basta rivendicarli (claim) manualmente.

{% include image.html url="/assets/img/2023-09-07-incompatible-disk-warning.png" description="Immagine 2 - Disco marcato come non compatibile" alt="Disco marcato come non compatibile" width=1817 height=683 %}

{% include image.html url="/assets/img/2023-09-07-disk-claiming.png" description="Immagine 3 - Claim manuale" alt="Claim manuale" width=1800 height=812 %}

## Risultato {#outcome}

Dopo qualche minuto dovresti avere il tuo cluster vSAN con ESXi annidato su PVE, funzionante ma non supportato.

Buon divertimento!
