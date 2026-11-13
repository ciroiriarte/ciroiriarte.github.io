---
title: Deploy di Apstra 4.2.0 su Proxmox VE
description: "Deploy passo passo delle appliance Apstra 4.2.0 AOS e ZTP"
date: 2023-10-03 00:00:00 -0300
permalink: /it/homelab/sdn/2023/10/03/deploying-apstra-4.2.0-on-PVE.html
lang: it
categories:
  - virtualization
  - networking
tags:
  - proxmox
  - apstra
---

## Appliance Apstra {#apstra-appliances}

Juniper non distribuisce vere e proprie appliance per deploy su KVM, ma immagini disco del sistema operativo in formato QCOW2:

**aos_server_4.2.0-236.qcow2**

Appliance principale del server Apstra, usata anche per i worker opzionali del setup scale-out: per i nodi worker si usa la stessa immagine (non l'ho trovato scritto nella documentazione, ma me l'ha detto uno di Juniper).

**apstra-ztp-4.2.0-34.qcow2**

Appliance opzionale per il Zero Touch Provisioning (ZTP) che esegue PXE+TFTP. Può essere usata come semplice TFTP insieme a un server DHCP già esistente.

## Installazione {#installation}

### Panoramica {#overview}

Per il dimensionamento delle VM, il vendor ha una [tabella di dimensionamento raccomandato](https://www.juniper.net/documentation/us/en/software/apstra4.2/apstra-install-upgrade/topics/ref/apstra-server-resources.html):

|Resource | Value|
|vCPU|8|
|RAM|64GB + 500MB per installed offbox agent|
|Disk|160GB|

Nella mia esperienza non servono tutte queste risorse, soprattutto di RAM. Per il mio ambiente di test ridurrò la RAM a 32GB e con ogni probabilità non è supportato, ci posso convivere, il tuo caso potrebbe essere diverso.

Creeremo le macchine virtuali vuote su Proxmox VE 7.4-15, importando poi i dischi QCOW2 come necessario. La procedura presuppone che tu abbia scaricato tutti i file in una directory di lavoro (curl/wget sono tuoi amici) su un nodo PVE.


### Apstra OS {#apstra-os}

#### Creazione della VM {#vm-creation}

Creeremo una macchina virtuale da CLI, con 4 vCPU e 32GB di RAM. 

La rete è servita tramite il bridge di default e lo storage tramite il repository ZFS locale. Le opzioni sono autoesplicative, adattale secondo necessità.

{% highlight shell %}
VMNAME=apstra-os-03.ipa.<my TLD>
VMID=$(pvesh get /cluster/nextid)
STORAGE=local-zfs
VCPU=4
VRAM=32768
VLANLAB=<my vlan>
BRIDGE=vmbr0

# OS doesn't support UEFI
qm create ${VMID} --name ${VMNAME} \
--bios seabios --machine q35 \
--ostype l26 --agent 1 \
--sockets 1 --cores ${VCPU} --cpu cputype=kvm64 \
--scsihw virtio-scsi-single \
--memory ${VRAM} \
--net0 model=virtio,bridge=${BRIDGE},firewall=0,tag=${VLANLAB}
{% endhighlight %}

#### Importazione del disco {#importing-disk}

Ora importeremo il file QCOW2 fornito da Juniper.

{% highlight shell %}
VMNAME=apstra-os-03.ipa.<my TLD>
VMID=$(qm list|grep ${VMNAME}|awk '{ print $1 }')
STORAGE=local-zfs

qm disk import ${VMID} aos_server_4.2.0-236.qcow2  ${STORAGE}
qm set ${VMID} -scsi0 ${STORAGE}:vm-${VMID}-disk-1
qm set ${VMID} --boot order=scsi0
{% endhighlight %}

#### Disco aggiuntivo {#additional-disk}

Secondo la documentazione, il disco del sistema operativo è di soli 80GB e opzionalmente si può aggiungere un secondo disco da 80GB. Dato che non costa molto e non userò nodi worker aggiuntivi, aggiungerò il secondo disco.

{% highlight shell %}
VMNAME=apstra-os-03.ipa.<my TLD>
VMID=$(qm list|grep ${VMNAME}|awk '{ print $1 }')
STORAGE=local-zfs

qm set ${VMID} --scsi1 ${STORAGE}:80
# we start the VM
qm start ${VMID}
{% endhighlight %}

### Appliance ZTP {#ztp-appliance}

DHCP e TFTP non sono particolarmente esigenti, bastano 2 vCPU e 4GB di RAM. 

La rete è servita tramite il bridge di default e lo storage tramite il repository ZFS locale. Le opzioni sono autoesplicative, adattale secondo necessità.

{% highlight shell %}
VMNAME=apstra-ztp-03.ipa.<my TLD>
VMID=$(pvesh get /cluster/nextid)
STORAGE=local-zfs
VCPU=2
VRAM=4096
VLANLAB=<my vlan>
BRIDGE=vmbr0

# OS doesn't support UEFI
qm create ${VMID} --name ${VMNAME} \
--bios seabios --machine q35 \
--ostype l26 --agent 1 \
--sockets 1 --cores ${VCPU} --cpu cputype=kvm64 \
--scsihw virtio-scsi-single \
--memory ${VRAM} \
--net0 model=virtio,bridge=${BRIDGE},firewall=0,tag=${VLANLAB}
{% endhighlight %}

#### Importazione del disco {#importing-disk-1}

Ora importeremo il file QCOW2 fornito da Juniper.

{% highlight shell %}
VMNAME=apstra-ztp-03.ipa.<my TLD>
VMID=$(qm list|grep ${VMNAME}|awk '{ print $1 }')
STORAGE=local-zfs

qm disk import ${VMID} apstra-ztp-4.2.0-34.qcow2  ${STORAGE}
qm set ${VMID} -scsi0 ${STORAGE}:vm-${VMID}-disk-1
qm set ${VMID} --boot order=scsi0
qm start ${VMID}
{% endhighlight %}

## Configurazione iniziale {#initial-configuration}
### Setup di AOS {#aos-setup}

1. Cerca l'IP dell'appliance nei lease del tuo DHCP e connettiti via SSH con admin/admin.
2. Al primo login imposta una nuova password, come richiesto.
3. Nell'assistente forzato imposta anche la password della UI di Apstra come proposto. Annulla nel menu principale dopo aver impostato la password.
4. Cambia l'hostname con qualcosa che abbia senso per il tuo ambiente. Con l'utente admin esegui:
{% highlight shell %}
sudo aos_hostname apstra-os-03.ipa.<my TLD>
{% endhighlight %}
{:start="5"}
3. Regola il fuso orario in base al tuo ambiente.
{% highlight shell %}
sudo timedatectl set-timezone <my TZ>
{% endhighlight %}
{:start="6"}
1. Come admin, aggiorna il sistema operativo. Molto probabilmente Juniper ti dirà che non è supportato. L'unico problema che ho avuto in passato è stato con la 4.1.0, che si è rotta perché c'era una libreria Juniper a livello di sistema che ha mandato in crisi un'applicazione containerizzata (chi l'avrebbe detto) e ha richiesto un aggiornamento manuale delle dipendenze per sistemarla. Con la 4.1.2 e ora con la 4.2.0 è andato tutto liscio; verranno menzionati dei file di pam.d, mantieni i file modificati localmente.
{% highlight shell %}
sudo apt update
sudo apt upgrade -y
{% endhighlight %}
{:start="7"}
1. Installa il guest agent di QEMU
{% highlight shell %}
sudo apt install -y qemu-guest-agent
{% endhighlight %}
{:start="8"}
1. Riavvia dopo l'aggiornamento completo del sistema
sudo shutdown -r now

### Setup dell'appliance ZTP {#ztp-appliance-setup}

1. Cerca l'IP dell'appliance nei lease del tuo DHCP e connettiti via SSH con admin/admin.
2. Imposta l'hostname

 {% highlight shell %}
sudo hostnamectl set-hostname apstra-ztp-03.ipa.<my TLD>
sudo sh -c 'echo "127.0.0.1 apstra-ztp-03.ipa.<my TLD>" >> /etc/hosts'
{% endhighlight %}
{:start="3"}
3. Regola il fuso orario in base al tuo ambiente.
{% highlight shell %}
sudo timedatectl set-timezone <my TZ>
{% endhighlight %}
{:start="4"}
1. Ripulisci la struttura di configurazione pasticciata: per qualche motivo quelli di Juniper hanno pensato che fosse una buona idea creare una directory dove dovrebbe esserci un file, e questo manda in crisi il processo di upgrade di Ubuntu. Sistemiamo (ma cosa fate, Juniper?!)
 {% highlight shell %}
sudo rmdir /etc/udev/rules.d/70-persistent-net.rules
{% endhighlight %}
{:start="5"}
1. Aggiorna il sistema operativo. Di nuovo, probabilmente Juniper ti dirà che non è supportato.
{% highlight shell %}
sudo apt update
sudo apt upgrade -y
{% endhighlight %}
{:start="6"}
7. Nella Web UI di Apstra, crea un utente con il ruolo device_ztp. Lo useremo nel prossimo passaggio.
8. Tornando sull'appliance ZTP, configura l'applicazione perché riporti al server AOS. Per qualche motivo non funziona con l'FQDN ma solo con l'IP.
{% highlight shell %}
cat > /containers_data/status/app/aos.conf <<EOF
{
   "ip": "<your-aos-ip>",
   "user": "<your ztp user>",
   "password": "<the super secure password>"
}
EOF
{% endhighlight %}
{:start="8"}
1. Installa il guest agent di QEMU
{% highlight shell %}
sudo apt install -y qemu-guest-agent
{% endhighlight %}
{:start="9"}
7. Riavvia la macchina virtuale
{% highlight shell %}
sudo shutdown -r now
{% endhighlight %}

## Migrazione dalla 4.1.2 {#migration-from-412}

Se hai già un ambiente funzionante, molto probabilmente vorrai migrare tutta la configurazione sulla nuova installazione: c'è uno script da eseguire sul nuovo server Apstra.

Tieni presente che lo script fallirà se ci sono modifiche non committate o se i dispositivi non sono raggiungibili. Assicurati che lo stato in esecuzione dell'ambiente di origine sia pulito (nessun errore).

{% highlight shell %}
aos_import_state --ip-address apstra-os-02.ipa.<my TLD> --username admin
{% endhighlight %}

Nota: 
- La migrazione della configurazione sostituirebbe anche la password della web UI con quella della configurazione del server originale.
