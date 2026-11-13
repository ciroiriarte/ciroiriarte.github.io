---
title: Configurare i dispositivi JunOS per Juniper Support Insights
description: Guida alla configurazione dei NE per permettere a vLWC di connettersi ed estrarre informazioni.
date: 2023-12-27 00:00:00 -0300
permalink: /it/datacenter/networking/2023/12/27/setting-up-junos-devices-for-jsi.html
lang: it
categories:
  - networking
tags:
  - juniper
  - junos
---

## Intro {#intro}

Tornando sul binario "supportato", dopo aver distribuito vLWC bisogna preparare i dispositivi da monitorare. Non riesco a trovare una guida concisa per configurare correttamente i network element per JSI, quindi condivido i miei appunti dopo un lungo esercizio di tentativi ed errori.

<!--more-->

Dopo aver letto le [JSI FAQ](https://www.juniper.net/documentation/us/en/software/jsi/jsi-on-jsp-faqs/topics/concept/jsi-faq-list.html), la mia interpretazione è che su ogni network element ci serve:

1. NETCONF-SSH abilitato
2. SFTP abilitato
3. Un account utente di processo dedicato a JSI/vLWC con permessi sufficienti (principio del minimo privilegio)

Una panoramica di come funziona la raccolta dei dati si trova in questo [flyer](https://www.juniper.net/content/dam/www/assets/flyers/us/en/juniper-support-insights-security-and-privacy-overview.pdf)


{% include image.html url="/assets/img/2023-12-27_datacollection_overview.png" description="Immagine 1 - Panoramica della raccolta dei dati" alt="Panoramica del flusso" width=1102 height=553 %}

## Prerequisiti {#pre-requirements}

### Coppia di chiavi SSH {#ssh-key-pair}

Ci serve una coppia di chiavi SSH pubblica/privata per l'utente. Puoi crearla su qualsiasi macchina Linux. 

**Nota:** Strada facendo ho scoperto che JunOS non accetta chiavi DSA ma solo RSA.

{% highlight shell %}
ciro.iriarte@jhost01:~> ssh-keygen -t rsa -C "JSI process user" -f ~/.ssh/id_rsa-jsi
Generating public/private rsa key pair.
Enter passphrase (empty for no passphrase): <-- make sure you input a passphrase
Enter same passphrase again: 
Your identification has been saved in /home/ciro.iriarte/.ssh/id_rsa-jsi
Your public key has been saved in /home/ciro.iriarte/.ssh/id_rsa-jsi.pub
The key fingerprint is:
SHA256:vMRG09Sd7BR1Q5P7B+9RakR2thSR3Md3bBOtYmm+VVc JSI process user
The key's randomart image is:
+---[RSA 3072]----+
|          .. o+&@|
|         o  . B*E|
|        o .  *.=O|
|       + .  = =o+|
|        S  + o =+|
|       o .  . +.+|
|        .    + .o|
|            .   .|
|                 |
+----[SHA256]-----+
{% endhighlight %}

Userai:
- il contenuto di *~/.ssh/id_rsa-jsi.pub* per configurare l'accesso negli switch
- il contenuto di *~/.ssh/id_rsa-jsi* + *la passphrase* verranno usati nel portale JSI per definire le credenziali di accesso.

### Comandi che devono essere permessi. {#actual-commands-that-should-be-permitted}

Dalle FAQ citate prima ricaviamo che i comandi che l'appliance eseguirà sono:

```
file list detail
show bgp summary
show chassis alarms
show chassis fpc
show chassis hardware extensive
show chassis routing-engine
show interfaces descriptions
show interfaces terse
show isis adjacency
show ospf neighbor
show rsvp neighbor
show system buffers
show system commit
show system core-dumps
show system license
show system uptime
show version
show vrrp detail
request support information
sftp
```

## Switch gestiti da Apstra {#apstra-managed-switches}

### NETCONF {#netconf}
NETCONF è già un requisito di Apstra, quindi dovresti averlo già coperto. Per verificarlo rapidamente, puoi controllare che la porta di default sia in ascolto di richieste di connessione:

{% highlight shell %}
ciro.iriarte@jhost01:~> nmap -p 830 ipf01-lf01.<TLD>
Starting Nmap 7.92 ( https://nmap.org ) at 2023-12-27 14:12 EST
Nmap scan report for ipf01-lf01.<TLD> (x.y.z.w)
Host is up (0.0012s latency).

PORT    STATE SERVICE
830/tcp open  netconf-ssh

Nmap done: 1 IP address (1 host up) scanned in 6.58 seconds
{% endhighlight %}

### SFTP {#sftp}
Non so se SFTP sia un requisito di Apstra, ma ho scoperto che tutti gli switch dell'ambiente Apstra avevano già il sottosistema SFTP abilitato. Se non è il tuo caso, ti basta un configlet per abilitarlo.

### Utente di processo {#process-user}

In questo ambiente non abbiamo TACACS+ (siamo nel 2023, team Juniper, possiamo avere LDAP una buona volta?). In pratica useremo i configlet di Apstra per creare un utente di processo da Apstra.

#### Creazione del configlet {#configlet-creation}

1. Raggiungi la pagina di creazione dei configlet.
{% include image.html url="/assets/img/2023-12-27_configlet00.png" description="Immagine 2 - Design --> Configlets" alt="Screenshot di Apstra" width=259 height=613 %}
{% include image.html url="/assets/img/2023-12-27_configlet01.png" description="Immagine 3 - Pulsante Create configlet &quot;" alt="Screenshot di Apstra" width=1352 height=262 %}

{:start="2"}
2. Compila i dati di base del configlet

{% include image.html url="/assets/img/2023-12-27_configlet02.png" description="Immagine 4 - Creazione effettiva del configlet" alt="Screenshot di Apstra" width=955 height=720 %}

{:start="3"}
3. Incolla il contenuto seguente nel corpo e clicca su "Create"
```
system {
    login {
        class jsi-class {
            permissions view-configuration;
            allow-commands "(file list detail)|(show bgp summary)|(show chassis alarms)|(show chassis fpc)|(show chassis hardware extensive)|(show chassis routing-engine)|(show interfaces descriptions)|(show interfaces terse)|(show isis adjacency)|(show ospf neighbor)|(show rsvp neighbor)|(show system buffers)|(show system commit)|(show system core-dumps)|(show system license)|(show system uptime)|(show version)|(show vrrp detail)|(request support information)|(sftp)";
            deny-commands "(clear)|(file)|(file show)|(help)|(load)|(monitor)|(op)|(request)|(save)|(set)|(start)|(test)";
            deny-configuration all;
        }
        user svcjsi {
            full-name "JSI process user";
            uid 2007;
            class jsi-class;
            authentication {
                ssh-rsa "ssh-rsa your-key-super-long-string JSI process user";
            }
        }
    }
}
```

**Nota:** Assicurati che l'UID sia univoco nel tuo ambiente. Ho visto post/note/documentazione a caso che citano l'UID 2000 (per altre implementazioni non correlate); io, super furbo, l'ho cambiato in 2001 per evitare conflitti con configurazioni che tutti potrebbero copiare e incollare, e a quanto pare chi ha implementato Apstra aveva avuto la stessa idea.

#### Importare il configlet nel blueprint {#importing-configlet-to-blueprint}

Per applicare davvero il configlet creato ai tuoi network element, devi:

1. Importare il configlet nel blueprint, assegnandolo ai dispositivi di interesse. Nel mio caso, tutti gli spine e i leaf switch.

{% include image.html url="/assets/img/2023-12-27_import-configlet00.png" description="Immagine 5 - Raggiungere la sezione di importazione" alt="Screenshot di Apstra" width=1455 height=437 %}

{% include image.html url="/assets/img/2023-12-27_import-configlet01.png" description="Immagine 6 - Selezionare il configlet e assegnarlo ai dispositivi di interesse" alt="Screenshot di Apstra" width=1020 height=777 %}

{:start="2"}
2. Fare il commit della configurazione perché venga inviata ai dispositivi.

{% include image.html url="/assets/img/2023-12-27_commit00.png" description="Immagine 7 - Richiesta di invio delle modifiche ai NE" alt="Screenshot di Apstra" width=1337 height=491 %}

{% include image.html url="/assets/img/2023-12-27_commit01.png" description="Immagine 8 - Compilare il changelog" alt="Screenshot di Apstra" width=976 height=377 %}

## Switch standalone {#standalone-switches}

Questi switch non sono gestiti da Apstra né da altri manager, e non ci sono nemmeno TACACS+ o servizi simili di autenticazione o RBAC (ho già detto che mi piacerebbe avere LDAP per riutilizzare i servizi di autenticazione esistenti?). Dato che sono solo 2, la configurazione manuale e locale non dovrebbe essere un problema.

Collegati allo switch con un utente admin, in modalità edit.

### NETCONF {#netconf-1}

Abilitiamo il servizio. I ragazzi dell'automazione, quelli fighi, raccomandano gli ultimi 3 comandi per l'interoperabilità, ma visto che vLWC è uno strumento chiuso di Juniper per JunOS, potrebbe aspettarsi la configurazione di default, meno standard e non conforme. Qualcosa da monitorare e verificare dopo aver aggiunto gli switch a JSI.

```
set system services netconf ssh
set system services netconf rfc-compliant
set system services netconf yang-compliant 
set system services netconf hello-message yang-module-capabilities advertise-standard-yang-modules
```

### SFTP {#sftp-1}

Il sottosistema SFTP va abilitato, sembra essere disabilitato di default.

```
set system services ssh sftp-server
```

### Utente di processo {#process-user-1}

1. Creiamo la classe utente con il livello di accesso richiesto
```
set system login class jsi-class permissions view-configuration
set system login class jsi-class allow-commands "(file list detail)|(show bgp summary)|(show chassis alarms)|(show chassis fpc)|(show chassis hardware extensive)|(show chassis routing-engine)|(show interfaces descriptions)|(show interfaces terse)|(show isis adjacency)|(show ospf neighbor)|(show rsvp neighbor)|(show system buffers)|(show system commit)|(show system core-dumps)|(show system license)|(show system uptime)|(show version)|(show vrrp detail)|(request support information)|(sftp)"
set system login class jsi-class deny-commands "(clear)|(file)|(file show)|(help)|(load)|(monitor)|(op)|(request)|(save)|(set)|(start)|(test)"
set system login class jsi-class deny-configuration all
```

2. Creiamo l'utente, usando la classe creata prima. Usa la tua chiave pubblica, non la mia!
```
set system login user svcjsi class jsi-class
set system login user svcjsi full-name "JSI process user"
set system login user svcjsi uid 2007
set system login user svcjsi authentication ssh-rsa "ssh-rsa your-key-super-long-string JSI process user"
```

### Commit finale {#final-commit}

3. Fare il commit della configurazione (sia servizio che utente)
```
commit
```

## Testare NETCONF a mano {#testing-netconf-by-hand}

Prima di passare per tutto l'apparato di JSI, il mio consiglio è fare un test locale di base con l'utente che abbiamo creato.

Accedi a una macchina Linux con accesso agli switch e alla chiave privata dell'utente che abbiamo creato, e prova a connetterti allo switch usando NETCONF

{% highlight shell %}
# We start the ssh key agent
eval $(ssh-agent)

# We add the key to the agent, the command will prompt for the key passphrase
ssh-add ~/.ssh/id_rsa-jsi

# We try a connection on default port
MYSWITCH=host.tld
ssh svcjsi@$MYSWITCH -p 830 -s netconf
{% endhighlight %}

La risposta dovrebbe essere simile a

{% highlight xml %}
<!-- No zombies were killed during the creation of this user interface -->
<!-- user svcjsi, class j-jsi-class -->
<nc:hello xmlns:nc="urn:ietf:params:xml:ns:netconf:base:1.0">
   <nc:capabilities>
    <nc:capability>urn:ietf:params:netconf:base:1.0</nc:capability>
    <nc:capability>urn:ietf:params:netconf:capability:candidate:1.0</nc:capability>
    <nc:capability>urn:ietf:params:netconf:capability:confirmed-commit:1.0</nc:capability>
    <nc:capability>urn:ietf:params:netconf:capability:validate:1.0</nc:capability>
    <nc:capability>urn:ietf:params:netconf:capability:url:1.0?scheme=http,ftp,file</nc:capability>
    <nc:capability>urn:ietf:params:xml:ns:netconf:base:1.0?module=ietf-netconf&amp;revision=2011-06-01</nc:capability>
    <nc:capability>urn:ietf:params:xml:ns:netconf:capability:candidate:1.0</nc:capability>
    <nc:capability>urn:ietf:params:xml:ns:netconf:capability:confirmed-commit:1.0</nc:capability>
    <nc:capability>urn:ietf:params:xml:ns:netconf:capability:validate:1.0</nc:capability>
    <nc:capability>urn:ietf:params:xml:ns:netconf:capability:url:1.0?scheme=http,ftp,file</nc:capability>
    <nc:capability>urn:ietf:params:xml:ns:yang:ietf-inet-types?module=ietf-inet-types&amp;revision=2013-07-15</nc:capability>
    <nc:capability>urn:ietf:params:xml:ns:yang:ietf-netconf-monitoring</nc:capability>
    <nc:capability>http://xml.juniper.net/netconf/junos/1.0</nc:capability>
    <nc:capability>http://xml.juniper.net/dmi/system/1.0</nc:capability>
  </nc:capabilities>
  <nc:session-id>65596</nc:session-id>
</nc:hello>
]]>]]>
{% endhighlight %}

## È tutto qui? {#is-that-it}

Beh, per la configurazione dei NE dovrebbe essere tutto. Ora dovresti poter accedere al portale JSI e fare l'onboarding dei dispositivi (ragazzi di Juniper, per favore aggiungete il supporto per gli FQDN nel form oltre agli indirizzi IP).

Buon divertimento!

## Altri documenti di riferimento {#more-reference-documents}

Nel caso tu stia ancora leggendo, questi sono alcuni documenti e appunti che ho consultato durante il processo.

- [Establish an SSH Connection for a NETCONF Session](https://www.juniper.net/documentation/us/en/software/junos/netconf/topics/topic-map/netconf-ssh-connection.html)  
- [Managing Juniped devices with SSH and NETCONF](https://www.tinfoilcipher.co.uk/2021/07/29/ansible-and-juniper-junos-managing-devices-with-ssh-and-netconf/)
- [Example: Configuring User Permissions with Access Privileges for Operational Mode Commands](https://www.juniper.net/documentation/en_US/junos/topics/example/access-privileges-individual-operational-mode-commands-configuring.html)
- [Connect to the NETCONF Server Using SSH](https://www.juniper.net/documentation/us/en/software/junos/netconf/topics/task/netconf-session-connecting-to-server.html)
- [Technical note on using SSH keys with JunOS](https://supportportal.juniper.net/s/article/Junos-Generating-SSH-RSA-keys-locally-on-devices-running-Junos-OS)

## Errori noti {#known-errors}

### JSI segnala credenziali errate {#jsi-reporting-wrong-credentials}

Durante i miei test ho scoperto che il portale web di JSI non gestisce l'aggiornamento delle credenziali. Puoi salvare le modifiche, vedi le nuove informazioni nel portale web, ma sembra che non arrivino al loro backend. Ho dovuto eliminare e ricreare le credenziali nel portale web perché funzionassero.

### NETCONF segnalato come non configurato {#netconf-reported-as-not-configured}

Durante i miei test ho potuto confermare manualmente che NETCONF era configurato correttamente, ma JSI continuava a segnalare:

```
The NETCONF subsystem is not enabled on the devices with the listed IP addresses. Please check and correct these entries
```

Il team JSI ha spiegato che c'era un timer che non permetteva al dialogo NETCONF di terminare correttamente. L'hanno risolto da parte loro ampliando la configurazione del timeout; non so se sia un parametro valido per tutta la piattaforma o se vada richiesto per i tuoi specifici nodi/siti/account.

Puoi citare il Juniper SR # 2023-1228-038580.
