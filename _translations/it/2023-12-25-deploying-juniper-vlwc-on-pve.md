---
title: Deploy di Juniper vLWC su PVE
description: "Walkthrough dell'analisi e del deploy di un Juniper Virtual Lightweight Collector per la funzionalità di \"call home\""
date: 2023-12-25 00:00:00 -0300
permalink: /it/datacenter/networking/2023/12/25/deploying-juniper-vlwc-on-pve.html
lang: it
categories:
  - networking
  - virtualization
tags:
  - juniper
  - junos
  - proxmox
---

## Intro {#intro}

Come per qualsiasi infrastruttura critica, i vendor di tecnologia offrono una funzionalità di "call-home" per i loro prodotti. Da più di un decennio (almeno per quanto ne so), vendor di storage come Hitachi o EMC offrono una soluzione che permette al vendor di collegarsi ai sistemi di tua proprietà, in modo che i reparti di supporto/assistenza ci lavorino direttamente invece di dirti al telefono cosa fare. Tra le altre funzionalità previste ci sono l'apertura proattiva di un ticket in caso di guasto hardware, l'estrazione/upload dei log e l'inventario dell'installato.

Questa funzionalità di call-home viene di solito fornita come software che gira su un appliance dedicato/fisico, come software da installare su un'istanza di un Sistema Operativo generico (Windows Server, SLES/RHEL/OEL/Debian) oppure, oggigiorno, come virtual appliance preconfezionato.

Implementare una funzionalità del genere è sempre una buona idea, perché permette al team di supporto del vendor di rispondere più in fretta quando ci sono guasti.

<!--more-->

## L'esigenza {#the-need}

Siamo stati contattati dal team di supporto Juniper, che ci proponeva un appliance WLC in grado di offrire capacità di call-home e di tenere sotto controllo il nostro installato. Questo appliance fa parte della loro iniziativa Juniper Support Insights (JSI).

Uno di questi appliance fisici è in viaggio verso uno dei nostri siti. Nel frattempo, sto seguendo un deploy di laboratorio che potrebbe trarre beneficio dal supporto rapido e dalle funzionalità di inventario. Approfondendo l'argomento, il team Juniper ha detto che esiste una versione virtuale dell'appliance rilasciata di recente.

La [documentazione](https://www.juniper.net/documentation/us/en/software/jsi/vlwc-deploy/topics/topic-map/install-verify-vlwc.html) ufficiale per gli ambienti vSphere è piuttosto lineare e puoi semplicemente seguirla se lavori su un ambiente supportato. Nel mio caso, l'ambiente "sidecart" di supporto del laboratorio non ha VMware vSphere, ma Proxmox VE.

Farò il deploy di vLWC su Proxmox VE per tenere sotto controllo gli switch QFX gestiti da Apstra e gli switch EX che compongono anche la rete OOBM degli stessi QFX.

## Here be dragons. {#here-be-dragons}

{% include image.html url="/assets/img/2023-12-25_1570-theatrum-orbis-terrarum-map-monsters.jpg" link="https://education.nationalgeographic.org/resource/here-be-dragons/" description="Immagine 1 - Mappa dei mostri del Theatrum Orbis Terrarum, 1570" width=860 height=580 %}

Come avvertimento, devo sottolineare che la configurazione che sto per eseguire e condividere con te non è supportata da Juniper, e il tuo Service Manager ti guarderà storto, ti griderà contro o ti ignorerà del tutto (a seconda del tipo di rapporto che avete) se mai chiederai aiuto per fare il deploy di vLWC su KVM. Nel nostro caso, do il benvenuto ad Alejandro per il supporto amministrativo!.

Ricorda anche che "non supportato" non vuol dire che non sia tecnicamente possibile. Vuol dire solo che sei da solo. Spero che prima o poi venga aggiunto il supporto per Proxmox e/o KVM.

Sì, otterrò supporto tramite un appliance "non supportato". Si qualifica come ossimoro?

## Architettura di rete {#network-architecture}
### Ambiente di laboratorio sidecart {#lab-sidecart-environment}
Nel laboratorio abbiamo un ambiente con il solito insieme di vendor e tecnologie con cui lavoriamo. Quella configurazione include una rete IP Fabric EVPN/VXLAN che serve diversi clienti. Ci si aspetta che quella rete e le piattaforme dei clienti vengano reinstallate o riorganizzate in qualsiasi momento.

Per fornire alcuni servizi essenziali stabili, abbiamo costruito un piccolo ambiente parallelo con qualche switch e server PVE su cui far girare gli elementi che devono essere sempre disponibili:

- Piattaforma di accesso remoto
- Servizi di autenticazione
- Strumenti legati alla sicurezza
- Strumenti di monitoraggio
- Soluzioni per firmware e hardware

Con questo ambiente "sidecart", qualunque cosa serva riorganizzare nell'ambiente principale, non perderemo mai la capacità di amministrazione.

Per l'ambito della nostra discussione, l'ambiente logico è più o meno questo:

{% include image.html url="/assets/img/2023-12-25_lab-environment.svg" description="Immagine 2 - Ambiente di rete di gestione di riferimento" alt="Panoramica delle reti del laboratorio" %}

Fisicamente, il sidecart è solo una coppia di switch Cisco Nexus in stack per fornire servizi L2 ridondati a 1GbE/10GbE, e la rete OOBM è una coppia di switch Juniper EX che offrono connettività a 1GbE agli switch e alle schede server IPMI.

Logicamente, la configurazione è piuttosto articolata e fornisce cose come controllo degli accessi e segmentazione di rete tramite OPNSense, che offre funzionalità L3 e di filtraggio. Vogliamo che gli utenti si autentichino con username/password + OTP, poi arriviamo ai Jump host usando Guacamole:

{% include image.html url="/assets/img/2023-12-25_lab-environment-flows.svg" description="Immagine 3 - Flusso di accesso remoto" alt="Accesso remoto" %}

La mia aspettativa naturale era fare il deploy dell'appliance di call-home accanto ad altri appliance di supporto come Apstra o LibreNMS.

{% include image.html url="/assets/img/2023-12-25_lab-environment-plus-vlwc.svg" description="Immagine 4 - Aggiungere vLWC al quadro" alt="vLWC nel quadro" %}

Questo è rilevante per la prossima sezione.

### Topologia di rete richiesta {#required-network-topology}

Leggendo la [guida al deploy](https://www.juniper.net/documentation/us/en/software/jsi/vlwc-deploy/topics/concept/system-requirements.html), si vede che richiede 3 interfacce di rete:

Interfaccia|Indirizzo IP supportato|Ruolo
---|---|---
Internal|Indirizzo IPv4 o IPv6|Usata per la connessione agli switch da monitorare. Qui c'è anche la default route.
External|Solo indirizzo IPv4|Usata per collegarsi alla Morte Nera (il call-home vero e proprio)
Management|Solo indirizzo IPv4|Usata per l'accesso al captive portal (portale web presentato dall'appliance con il suo stato)

Potremmo provare a rispettare i requisiti e forzare l'appliance dentro il nostro ambiente:

{% include image.html url="/assets/img/2023-12-25_lab-environment-plus-vlwc-forced-compliance.svg" description="Immagine 5 - Conformità forzata" alt="vLWC nel quadro" %}


Non mi mette a mio agio: VM collegate a segmenti diversi che dovrebbero interagire solo attraverso il firewall non erano un'opzione nel nostro caso.

### Analisi dell'appliance: tentativi ed errori {#appliance-analysis-trial--error}

Ho fatto diverse prove di deploy su KVM, in laboratorio isolato, per verificare cosa succede con la configurazione di rete e analizzare cosa serve per farlo funzionare con una sola interfaccia.

Ti risparmio i dettagli, ma il riassunto dei risultati è:

#### **Prima prova:** 3 reti con DHCP (internal + external + management) {#first-run-3-networks-with-dhcp-internal--external--management}
*"int"* mantiene la default route  
*"ext"* ha route statiche per raggiungere la Morte Nera (JNI)  
*"cap"* è usata per il captive portal (pagina di stato dell'appliance)

Le route statiche in questione (se sei curioso, quei segmenti appartengono ad AWS e DigitalOcean):

```
35.71.174.221 via <ext segment gateway> dev ext 
35.83.44.146 via <ext segment gateway> dev ext 
52.223.32.79 via <ext segment gateway> dev ext 
54.149.98.110 via <ext segment gateway> dev ext 
54.149.222.60 via <ext segment gateway> dev ext 
68.183.248.21 via <ext segment gateway> dev ext 
138.197.235.241 via <ext segment gateway> dev ext 
```
**Prima conclusione:** potremmo dover smanettare con l'appliance per evitare che installi le route statiche, a meno che l'installazione delle route statiche non fallisca in silenzio per l'assenza dell'interfaccia EXT.

Il binding dei servizi SSHD e Captive Portal non è limitato a nessuna interfaccia in particolare. 

{% highlight shell %}
root@ggc-lnx:~# lsof -n -sTCP:LISTEN -i :443
COMMAND     PID USER   FD   TYPE DEVICE SIZE/OFF NODE NAME
docker-pr 20982 root    4u  IPv4 106963      0t0  TCP *:https (LISTEN)
docker-pr 20994 root    4u  IPv6 107636      0t0  TCP *:https (LISTEN)
root@ggc-lnx:~# lsof -n -sTCP:LISTEN -i :22 
COMMAND PID USER   FD   TYPE DEVICE SIZE/OFF NODE NAME
sshd    543 root    3u  IPv4  17619      0t0  TCP *:ssh (LISTEN)
sshd    543 root    4u  IPv6  17621      0t0  TCP *:ssh (LISTEN)
{% endhighlight %}

**Seconda conclusione:** non serve toccare la configurazione del binding dei servizi, tutti ascoltano su tutte le interfacce.

Quindi il comportamento "non rispondere su EXT" dovrebbe con ogni probabilità arrivare dalle regole del firewall, tranne che non è così (non esiste nessuna regola di firewall che limiti le richieste SSH in ingresso a una determinata interfaccia), quel comportamento era una costruzione della mia immaginazione e nella documentazione non se ne parla. 

Il mio test ssh è stato fatto da un client nella stessa subnet che ospita l'interfaccia EXT. La mia ipotesi a naso è che qualsiasi altro tentativo di connessione di client remoti da Internet dovrebbe fallire perché il default gateway è installato su INT. 

Comunque, ragazzi, non mettete l'appliance direttamente collegato a Internet senza filtri in ingresso, se potete evitarlo.

**Terza conclusione:** non serve toccare la configurazione del firewall.

**Quarta conclusione:** lo screenshot seguente mostra l'aspetto di un appliance in salute.

{% include image.html url="/assets/img/2023-12-25_status-deployment-test-3if.png" description="Immagine 6 - Stato dell'appliance con il layout di rete supportato" alt="Stato dell'appliance" width=782 height=754 %}

#### **Seconda prova:** configurazione con 1 rete con DHCP (internal) {#second-run-1-network-setup-with-dhcp-internal}
*"int"* mantiene la default route, fornisce l'accesso al captive portal (pagina di stato dell'appliance)  
*"ext"* viene riportata con stato in errore  

**Quinta conclusione:** anche se la pagina di stato mostra un "Connection Status" in errore per "External Network", si vede che abbiamo comunque "Juniper Cloud Connected" e "Cloud Provisioned". La mia interpretazione è che c'è un errore perché non esiste un'interfaccia EXT configurabile, ma è solo estetico, dato che abbiamo accesso a Internet usando INT con la default route.

{% include image.html url="/assets/img/2023-12-25_status-deployment-test-1if.png" description="Immagine 6 - Stato dell'appliance con una sola interfaccia" alt="Stato dell'appliance" width=775 height=767 %}

Posso anche confermare che, controllando l'appliance a livello di OS, non ci sono route statiche. Per un deploy con una sola interfaccia che si connette a JSI non servono modifiche.

## L'appliance {#the-appliance}
### Primi passi amministrativi. {#first-administrative-steps}

Devi chiedere due cose al tuo team di supporto Juniper:
- Accesso a Juniper Support Insights per richiedere l'appliance
- Che vengano configurati i permessi corretti per gestire/usare l'appliance. Abbiamo una miriade di account di supporto e qualcosa non era configurato bene per il mio account in JSI.

### Come richiedere l'appliance. {#how-to-request-the-appliance}

1. Una volta che hai i permessi giusti sul tuo utente, vai al [Juniper Support Portal](https://supportportal.juniper.net/)
2. Richiedi l'appliance tramite il portale web.
{% include image.html url="/assets/img/2023-12-25_request_appliance_00.png" description="Immagine 7 - Accedere alla sezione collectors" alt="Sezione collectors" width=887 height=368 %}
  
{% include image.html url="/assets/img/2023-12-25_request_appliance_01.png" description="Immagine 8 - Clicca su &quot;Request Virtual Lightweight Collector&quot;" alt="Richiesta" width=1433 height=217 %}
  
{% include image.html url="/assets/img/2023-12-25_request_appliance_02.png" description="Immagine 9 - Clicca su &quot;Fill-in and submit form&quot;" alt="Richiesta" width=1494 height=775 %}

{:start="3"}
3. Entro un'ora dovresti ricevere un'email da *do_not_reply@juniper.net* con un link per scaricare l'appliance. Il file viene eliminato dopo 7 giorni, dopodiché dovresti richiedere di nuovo l'appliance.

## Deploy {#deployment}

### Cosa ricevi da Juniper? {#what-are-you-receiving-from-juniper}

Quando scarichi l'appliance dal sito di supporto Juniper, ottieni un file OVA con un nome simile a vLWC-${VERSION}-$(SERIAL_NUMBER).ova. Nel mio caso era la versione 2.3.26.

Un file OVA è sostanzialmente un file ZIP con un'immagine disco VMDK e un file OVF con la definizione della macchina virtuale da creare, inclusi i metadati e la definizione di cosa l'utente deve inserire durante il rollout (salteremo il file manifest ai fini di questa discussione).

Il VMDK a quanto pare è generico per tutti i clienti; il file OVF include il numero di serie specifico del tuo deploy e va incorporato durante l'istanziazione/rollout.

### Configurazione iniziale {#initial-setup}

Con la personalizzazione OVF disponibile via vSphere + VMware Tools, alcuni parametri vengono passati alla VM al momento dell'istanziazione, ma questo non è supportato da Proxmox VE. Proxmox VE + cloud-init potrebbe offrire capacità simili, ma al momento l'appliance vLWC non lo supporta.

{% include image.html url="/assets/img/2023-12-25_missmatch.jpg" description="Immagine 10 - Capacità di autoconfigurazione, Proxmox VE a sinistra, Juniper vLWC a destra &quot;" alt="Disallineamento" width=1200 height=630 %}

Dovremmo modificare il disco originale prima di importarlo nella macchina virtuale. Cercherò di fare il minor numero possibile di modifiche.

- Modifiche necessarie
1. La configurazione di rete è già preimpostata nell'appliance per DHCP; dato che nell'ambiente sidecart abbiamo il DHCP, la lasceremo così. Altri ambienti potrebbero richiedere indirizzamento statico, fuori scope per il momento.
2. In ogni scenario, una modifica obbligatoria per l'appliance sarebbe inserire il numero di serie perché riporti correttamente a JSI. Servono due voci: una in chiaro, che recupereremo dal nome del file scaricato, e una cifrata, che dobbiamo recuperare dal file OVF.

- Modifiche opzionali
1. Adatteremo l'hostname per avere un inventario come si deve. Ho visto i log dell'appliance che riporta a casa l'hostname come nome del prodotto e versione del prodotto (ragazzi di Juniper, un hostname non serve a questo); al momento non sembra influire sulla funzionalità, ma terrò d'occhio la cosa e farò rollback se serve.
2. Timezone. L'appliance arriva preimpostata con la timezone UTC; la cambierò con la nostra. Bisognerà monitorare e fare rollback se questo causa problemi lato JSI.
3. QEMU Agent. Offre un po' di integrazione con PVE per aiutare nella gestione della VM.
4. Installare la mia chiave pubblica per il login di root, aiuta nel troubleshooting (lo so, non dovrei usare root su questo appliance, così come non dovrei farne il deploy su PVE/KVM 🙂)

***
**Aggiornamento 1**: sono stato contattato da qualcuno che sembra far parte del team operations di JSI, che mi ha chiesto gentilmente di annullare la modifica dell'hostname perché per loro rompe delle cose.

Come tentativo a lungo raggio, lo aggiungo come richiesta aggiuntiva per il PLM.  

***


Copia il file OVA sul tuo host PVE (scp è tuo amico) e segui la procedura qui sotto.

1. Prima di tutto, dobbiamo annotare il numero di serie nelle due rappresentazioni che ci serviranno.

{% highlight shell %}
# prepare the working directory
mkdir -p import/juniper
cd import/juniper
# at this point, copy the OVA file via SCP.
# verify file existance
ls -l vLWC-2.3.26-<serial>.ova
-rw-r--r-- 1 ciro.iriarte ipausers 2466766848 Dec 19 17:01 vLWC-2.3.26-<serial>.ova
# We extract the content of the ZIP file
mkdir vLWC-2.3.26-<serial>
tar -C vLWC-2.3.26-<serial>/ -xf vLWC-2.3.26-<serial>.ova
cd vLWC-2.3.26-<serial>/

# Recover the un-encrypted serial number from the filename and take note of the output of this command
basename -s .ova $(ls -1 ~/import/juniper/*ova)| awk -F "-" '{ print $NF }'

# Recover the encrypted serial number from the OVF file and take note of the output of this command
grep --color serial_number ~/import/juniper/vLWC-2.3.26-<serial>/vLWC-2.3.26-<serial>.ovf |awk '{ print $6 }'|cut -f 2 -d '"'

{% endhighlight %}

{:start="2"}
2. Montiamo il sistema per modificarlo
{% highlight shell %}
# Make sure you start in the same directory we were working before. We move to the directory containing the disk image.
cd vLWC-2.3.26-<serial>/

# Convert from VMDK to RAW
qemu-img  convert vLWC-2.3.26-<serial>-disk1.vmdk vLWC-2.3.26-<serial>-disk1.raw

# Bind disk to loopback device
losetup -f -P vLWC-2.3.26-<serial>-disk1.raw
# Confirm binding
losetup -l 

# Create a mount point for the vLWC system
mkdir -p /mnt/loop-root
# Mount the first partition
MYLOOP=$(losetup -l|grep vLWC | awk '{ print $1 }')
mount ${MYLOOP}p1 /mnt/loop-root/
mount -o bind /dev /mnt/loop-root/dev/
mount -o bind /proc /mnt/loop-root/proc/
chroot /mnt/loop-root/
{% endhighlight %}

{:start="3"}
3. Come detto, dobbiamo definire il numero di serie corretto. Questa sarebbe l'unica modifica obbligatoria
{% highlight shell %}
# Define variables with serial data for your appliance
MYSERIAL="your plain text serial number"
MYSERIALENCRYPTED="your encrypted serial number"

# Set encrypted serial parameter
echo $(cat /opt/jsas/etc/vlwc-status.json | jq --arg val "$MYSERIALENCRYPTED" '.properties.serial_number = $val') > /opt/jsas/etc/vlwc-status.json
# Set plain text serial
echo -n "$MYSERIAL" > /home/jsas/nfxserialnum

{% endhighlight %}

{:start="4"}
4. Modifiche opzionali. Le fai mentre sei ancora **dentro** l'ambiente chroot. Se vuoi, puoi mettere tutto il blocco in uno script.

{% highlight shell %}

##
# QEMU agent
##

# Temporary adjust name resolution to allow package installation from Internet
MYDNS="x.y.z.w"
mv /etc/resolv.conf{,.orig}
echo "nameserver $MYDNS" > /etc/resolv.conf
# We install QEMU agent
apt install qemu-guest-agent
# Restore original DNS resolution config
mv /etc/resolv.conf{.orig,}

##
# Hostname. We don't do this anymore until Juniper releases an update that moves the appliance version validation from the hostname.
##
#NO# MYHOSTNAME="short.TLD"
# We backup original setup
#NO# cp -p /etc/hostname{,.orig}
# We define new hostname
#NO# echo $MYHOSTNAME > /etc/hostname

# In case you did change the hostname, the rollback would be:
# mv /etc/hostname{,.mine}
# mv /etc/hostname{.orig,}
# hostname $(cat /etc/hostname)

##
# Timezone
##

# Set your preferred timezone. You can get a list from timedatectl list-timezones
timedatectl set-timezone <Region>/<Country>

##
# SSH key for root
##

# Create the missing directory
mkdir ~/.ssh
# Add your public key to the trusted keys
YOURPUBKEY="key-type your-full-public-key-should-go-here key-alias"
echo "$YOURPUBKEY" >> ~/.ssh/authorized_keys

{% endhighlight %}

{:start="5"}
5. Smontiamo l'immagine e sganciamo il dispositivo

{% highlight shell %}
# we exit the chroot
exit
# umount filesystems
umount /mnt/loop-root/dev /mnt/loop-root/proc /mnt/loop-root
# unbind device
losetup -d $MYLOOP
{% endhighlight %}

A questo punto, l'immagine disco contiene la configurazione richiesta per il tuo sito/istanza.

### Creazione della VM {#vm-creation}

Per una soluzione supportata su vSphere, il file OVF viene importato in vCloud Director o vCenter. Include la definizione della VM (quantità e tipo di CPU, RAM, dischi e adattatori di rete).

Non possiamo usare il file OVF per Proxmox VE; dovrebbe funzionare, ma in pratica ho trovato dei problemi di formattazione.

Collegati via SSH alla tua macchina PVE e crea uno script per fare il deploy della VM:

{% highlight shell %}
root@pve01:~/import/juniper# cat > import-vlwc.sh<<'EOF'
#!/bin/bash
# We set the bridge & the VLAN we need to integrate de VM to.
BRIDGE=vmbr0
VLAN=4089
# Storage destination for the appliance to live in
STORAGE=local-zfs
# Source disk image
DSK=vLWC-2.3.26-<serial>/vLWC-2.3.26-<serial>-disk1.raw

# We need the next VM ID available
NEWVM=$(pvesh get /cluster/nextid)
# Proper VM name
VMNAME=jsi-vlwc01.<my-TLD>

# We create the VM without disks. 6 vCPU + 16GB for up to 10k devices, most probably you can live with less resources.
qm create $NEWVM --name $VMNAME --bios seabios --machine q35 \
--numa 1 --sockets 1 --cores 6 \
--scsihw virtio-scsi-pci \
--memory 16384 \
--agent enabled=1

# We add the disk we have prepared, and attach it to the VM.
qm importdisk $NEWVM $DSK $STORAGE
qm set $NEWVM -scsi0 ${DISK} ${STORAGE}:vm-${NEWVM}-disk-0
# Boot device at BIOS
qm set $NEWVM --boot order=scsi0

# We add NIC with the correct VLAN mapping
qm set $NEWVM \
--net0 model=virtio,bridge=${BRIDGE},firewall=1,tag=${VLAN}

# We start the VM
qm start
EOF

# Allow the script to be executed
root@pve01:~/import/juniper# chmod +x import-vlwc.sh

# Create VM
root@pve01:~/import/juniper# ./import-vlwc.sh
{% endhighlight %}

Dopo un paio di minuti, dovresti riuscire a visitare la vista web del captive portal tramite l'FQDN dell'appliance (supponendo che tu abbia una corretta integrazione DHCP+DNS) o il suo indirizzo IP.

Usa il numero di serie in chiaro per fare login e cerca "Juniper Cloud Connected" + "Cloud Provisioned" per assicurarti che sia online.


## Lista dei desideri per il PLM {#wishlist-for-the-plm}

Nel caso passi di qui un Product Owner dell'appliance Juniper vLWC :), consiglierei di includere nel backlog quanto segue:

### 1- Supporto per una configurazione a interfaccia singola {#1--support-for-a-single-interface-setup}

Capisco perfettamente la configurazione a 3 interfacce per un appliance fisico che sta in colocation con un MX960 solitario in un sito remoto dimenticato da Dio. Si ha:
- Una porta "trusted" collegata a una rete OOBM che serve diversi NE o direttamente alla porta OOBM di un router solitario.
- Una porta "outside" che dà accesso a Internet, probabilmente proveniente da un NE sul lato ISP e di cui non ci si dovrebbe fidare (nessun servizio come SSH in ascolto).
- Una porta "management" che darebbe accesso all'appliance a un ingegnere in sito, probabilmente collegata direttamente al suo laptop.

La mia ipotesi poco informata è che l'appliance virtuale abbia sostanzialmente seguito un approccio "infiliamo a forza in una VM quello che avevamo nella versione [appliance fisico](https://www.juniper.net/documentation/us/en/hardware/lwc-hardware-guide/lwc/topics/concept/lwc-description.html)".

Una macchina virtuale con ogni probabilità verrà installata in un comodo datacenter TIER-qualcosa, in un cluster di virtualizzazione come si deve, con una configurazione logica molto elaborata per gestione e monitoraggio, con integrazioni L3 verso le destinazioni richieste e servizi come filtraggio/segmentazione fuori dall'appliance.

La richiesta sarebbe: per favore, supportate/consentite una configurazione a "interfaccia singola" come alternativa a quella a 3 porte. Oggi funziona così com'è, a parte gli errori legati a EXT nella pagina di stato.

### 2- Una distribuzione Linux più recente {#2--newer-linux-distribution}

A partire da vLWC-2.3.26, l'appliance si basa su Ubuntu 18.04.6 LTS, che è già [fuori dallo Standard Support da giugno 2023](https://wiki.ubuntu.com/Releases). Solo i sottoscrittori del supporto Ubuntu Pro riceveranno rilasci di patch minimi, e da una rapida verifica posso dire che sull'appliance installato non è disponibile (magari con persino una versione di openssl con dei bug?):

{% highlight shell %}
root@ggc-lnx:~# pro status
Failed to access URL: https://contracts.canonical.com/v1/resources?architecture=amd64&kernel=4.15.0-212-generic&series=bionic&virt=kvm
Cannot verify certificate of server
Please check your openssl configuration.
{% endhighlight %}

Le istanze di distribuzioni Linux vecchie e le implicazioni di sicurezza per un dato ambiente sono un tema trito e ritrito. Riassumerei la richiesta così: un refresh dell'OS è dovuto e Ubuntu 22.04.3 LTS è a vostra disposizione. No, "prima o poi ripacchetteremo una nuova versione dell'appliance con le patch applicate e dovrai rifare il deploy" non è accettabile

### 3- Supporto per PVE/KVM {#3--support-for-pvekvm}

Non tutte le realtà Juniper usano VMware vSphere sul lato compute e, se lo fanno, potrebbe non essere la scelta per ogni singolo deploy. Pur apprezzando il lavoro fatto nella preparazione del file [OVF](https://www.dmtf.org/standards/ovf) per automatizzare la configurazione iniziale, consiglio vivamente al vostro team di investire un po' di tempo nell'implementare il supporto per [cloud-init](https://cloudinit.readthedocs.io/en/latest/) nello script di configurazione iniziale, che è lo standard de facto per fare il deploy di virtual appliance in ambienti cloud (KVM on prem, vSphere, AWS, Azure, ecc).

Alcuni frutti a portata di mano:
- I driver di rete VirtIO sono già disponibili nell'appliance (consigliati per KVM/QEMU, non limitati a VMXNET3). Usati in questo deploy.
- Il QEMU agent si può installare facilmente dai repository Ubuntu preconfigurati nell'appliance (opzionale, copre parte della funzionalità di VMware Tools per KVM/QEMU). Usato in questo deploy.
- L'agent cloud-init si può installare facilmente dai repository Ubuntu preconfigurati nell'appliance. Non usato in questo deploy.

### 4- Consentire il cambio di hostname {#4--allow-for-hostname-change}

A causa di alcuni requisiti/convenzioni discutibili che abbiamo, dobbiamo assegnare un hostname adeguato alla VM. Sembra che venga usato per il versioning dell'appliance, come notato poco più su nell'articolo.
- Facciamo coincidere il nome della VM e l'hostname dell'OS a fini di inventario (consolidamento e controllo incrociato dei dati di più strumenti).
- Parte dei controlli SOX raccomanda che venga applicata una convenzione di naming degli hostname adeguata.
- La registrazione via DHCP aggiorna i record DNS; avere più di un appliance installato manda in confusione questa integrazione automatica.

Il mio forte consiglio è di spostare il reporting della versione dell'appliance in una voce di metadati apposita da qualche altra parte, e lasciare che un hostname sia un hostname.
