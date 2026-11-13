---
title: Integrare il sistema operativo degli appliance Apstra con FreeIPA
description: "Installazione del client IPA su appliance basati su Ubuntu per Apstra 4.2.0"
date: 2023-10-07 00:00:00 -0300
permalink: /it/homelab/sdn/2023/10/07/Integrating-Apstra-Appliances-OS-to-FreeIPA.html
lang: it
categories:
  - networking
  - security
tags:
  - apstra
  - freeipa
  - ubuntu
---

## Obiettivo {#intent}

Se lavori in un qualsiasi ambiente sensato con server Unix/Linux, di sicuro hai in piedi una qualche forma di autenticazione/autorizzazione centralizzata per l'accesso al sistema operativo. Oggi è LDAP o LDAP+Kerberos.

Nel mio caso, uso FreeIPA per l'ecosistema Linux.

## Gli appliance Apstra {#apstra-appliances}

Apstra è uno strumento di gestione della configurazione e monitoraggio per le reti dei Datacenter. Non credo sia un vero controller SDN (almeno nel concetto originale del termine) perché assomiglia di più a strumenti di gestione della configurazione come Puppet o Ansible. Ciononostante, fa parte dell'ecosistema degli strumenti SDN. 

Gli appliance Apstra sono basati su Ubuntu LTS e, per fortuna, abbiamo a disposizione il FreeIPA ufficiale. Molto probabilmente il tuo referente Juniper ti dirà che installare pacchetti ufficiali di Ubuntu non è supportato.

L'avevo già implementato con Apstra 4.1.0, 4.1.1 e 4.1.2, ma la 4.2.0 stavolta richiede una modifica. Funziona e, per la mia esperienza, non interferisce con le sue funzionalità; in ogni caso, è consigliabile provarlo in un ambiente di laboratorio prima di passare in produzione. Procedi a tuo rischio e pericolo.

## Presupposti {#assumptions}
1. Hai gli appliance dell'ecosistema Apstra (AOS, ZTP, worker) correttamente distribuiti
2. Il fuso orario corretto è già configurato
3. La configurazione del client NTP è a posto
4. La configurazione del client DNS è a posto

## Configurazione lato server FreeIPA {#freeipa-server-side-configuration}

Assicurati che il client abbia una voce DNS.

{% highlight shell %}
ipa dnsrecord-add <your domain> <client shortname> --a-rec <IPv4 for the client>
ipa dnsrecord-add <your domain> <client shortname> --aaaa-rec <IPv6 for the client>
{% endhighlight %}

## Librerie Python e AOS {#python-libraries-and-aos}

Be', questo è un caso speciale di Apstra 4.2.0. Ci sono moduli Python installati con *pip* al di fuori di ciò che forniscono i pacchetti basati su apt; a quanto pare servono alla piattaforma Apstra ma rompono altri strumenti come ipa-client-install sull'appliance AOS (non succede con l'appliance ZTP).

Appliance ZTP:

{% highlight shell %}
admin@apstra-ztp-03:~$ pip show cryptography
Name: cryptography
Version: 3.4.8
Summary: cryptography is a package which provides cryptographic recipes and primitives to Python developers.
Home-page: https://github.com/pyca/cryptography
Author: The Python Cryptographic Authority and individual contributors
Author-email: cryptography-dev@python.org
License: BSD or Apache License, Version 2.0
Location: /usr/lib/python3/dist-packages
Requires: 
Required-by: ansible-core, paramiko
{% endhighlight %}

Appliance AOS:

{% highlight shell %}
admin@apstra-os-03:~$ pip show cryptography
Name: cryptography
Version: 38.0.0
Summary: cryptography is a package which provides cryptographic recipes and primitives to Python developers.
Home-page: https://github.com/pyca/cryptography
Author: The Python Cryptographic Authority and individual contributors
Author-email: cryptography-dev@python.org
License: BSD-3-Clause OR Apache-2.0
Location: /usr/local/lib/python3.10/dist-packages
Requires: cffi
Required-by: paramiko
{% endhighlight %}

Nota che la versione su AOS è più recente e che i moduli risiedono in /usr/local/lib invece che in /usr/lib.

Un'applicazione basata su container come Apstra dovrebbe avere tutto ciò che le serve dentro il container e non dovrebbe richiedere né toccare le librerie a livello di host.

### Come influisce su ipa-client-install {#how-it-affects-ipa-client-install}
Lo strumento di configurazione di IPA fallisce con questo errore:

{% highlight shell %}
admin@apstra-os-03:~$ ipa-client-install 
Traceback (most recent call last):
  File "/usr/sbin/ipa-client-install", line 22, in <module>
    from ipaclient.install import ipa_client_install
  File "/usr/lib/python3/dist-packages/ipaclient/install/ipa_client_install.py", line 7, in <module>
    from ipaclient.install import client
  File "/usr/lib/python3/dist-packages/ipaclient/install/client.py", line 37, in <module>
    from ipalib import api, errors, x509
  File "/usr/lib/python3/dist-packages/ipalib/__init__.py", line 921, in <module>
    from ipalib.frontend import Command, LocalOrRemote, Updater
  File "/usr/lib/python3/dist-packages/ipalib/frontend.py", line 31, in <module>
    from ipalib.parameters import create_param, Param, Str, Flag
  File "/usr/lib/python3/dist-packages/ipalib/parameters.py", line 125, in <module>
    from ipalib.x509 import (
  File "/usr/lib/python3/dist-packages/ipalib/x509.py", line 91, in <module>
    @crypto_utils.register_interface(crypto_x509.Certificate)
**AttributeError: module 'cryptography.utils' has no attribute 'register_interface'. Did you mean: 'verify_interface'?**
{% endhighlight %}

Sembra che FreeIPA usasse una funzione che non era pensata per essere usata al di fuori dell'implementazione di capy/cryptography. Il team di quest'ultimo progetto [ha deciso di deprecare la funzione](https://github.com/pyca/cryptography/pull/7234) nella 38.0; installare la libreria più recente al di fuori di quanto fornisce la distro rompe il client FreeIPA da essa fornito.

Il progetto FreeIPA [si sta adeguando alla modifica upstream](https://github.com/freeipa/freeipa/pull/6455), e dovrebbe essere incluso dalla 4.11 in poi

### Il modo corretto di affrontare la cosa {#the-correct-way-of-dealing-with-this}

#### Regola d'oro {#golden-rule}

Non si toccano le librerie fornite dalla distribuzione Linux. Mai.

#### Strumenti a disposizione di chi impacchetta il software {#tools-at-hand-for-software-packagers}

I container sono una soluzione attuale per la distribuzione del software che potrebbe risolvere il problema. In effetti, Juniper usa container docker. Non capisco bene perché oggi sia un problema con l'appliance AOS di Apstra, ma impacchettare tutte le dipendenze dentro i container dovrebbe essere la strada giusta.


### Workaround per i clienti Juniper {#workaround-for-juniper-customers}

Tutto ciò che possiamo fare finché Juniper non impacchetta Apstra correttamente come insieme di immagini container è scegliere la strada meno brutta. In questo caso, ho ricompilato un pacchetto di Ubuntu 23.04, basato sul sorgente di FreeIPA 4.9.11, per Ubuntu 22.04 (su cui si basa l'appliance Apstra).

Aggiungeremo il repository solo per AOS; l'appliance ZTP può usare i pacchetti standard. 

{% highlight shell %}
sudo sh -c 'echo "deb http://download.opensuse.org/repositories/home:/ciriarte:/apstra-4.2.0-fix/xUbuntu_22.04/ /" | sudo tee /etc/apt/sources.list.d/home:ciriarte:apstra-4.2.0-fix.list'
sudo sh -c 'curl -fsSL https://download.opensuse.org/repositories/home:ciriarte:apstra-4.2.0-fix/xUbuntu_22.04/Release.key | gpg --dearmor | sudo tee /etc/apt/trusted.gpg.d/home_ciriarte_apstra-4.2.0-fix.gpg > /dev/null'
sudo chmod a+r /etc/apt/trusted.gpg.d/home_ciriarte_apstra-4.2.0-fix.gpg
sudo chmod a+r /etc/apt/sources.list.d/home:ciriarte:apstra-4.2.0-fix.list
sudo apt update
{% endhighlight %}

Dopo aver aggiunto il repository, segui semplicemente la procedura qui sotto.


## Configurazione dei client {#clients-configuration}

Per ogni client in questione, appliance ZTP, appliance AOS principale o worker, dovrai eseguire questi passaggi.

### Verifica del DNS {#dns-validation}
Il DNS è critico in questo ambiente, assicurati che i client riescano davvero a trovare i tuoi server IP.

1. Verifica che il client sia effettivamente configurato
{% highlight shell %}
dig _ldap._tcp.<your domain> SRV
{% endhighlight %}

{:start="2"}
1. Verifica che tutti i server previsti rispondano davvero. Ci sono scenari bizzarri in cui alcuni server rispondono e altri no.
{% highlight shell %}
dig @<recursor/resolver 1 IP>  _ldap._tcp.<your domain> SRV
dig @<recursor/resolver 2 IP>  _ldap._tcp.<your domain> SRV
{% endhighlight %}

### Installazione e configurazione del client {#client-installation--configuration}

Il client FreeIPA fa parte dei repository di default, basta installarlo con il gestore di pacchetti:

{% highlight shell %}
sudo apt install -y freeipa-client
sudo ipa-client-install --mkhomedir --enable-dns-updates \
 --domain=<IPA domain in lowercase> --realm=<IPA domain in uppercase>
{% endhighlight %}

### Limitare l'accesso SSH {#limit-ssh-access}

È buona pratica limitare l'accesso via SSH agli utenti che ne hanno davvero bisogno sul nodo. 

Ripensandoci, andrebbe fatto con il modulo HBAC di FreeIPA + pam_sss.so. Non ricordo perché in questo ambiente stiamo fissando il gruppo a livello di sshd, lo terrò per coerenza. **Da rivedere**

{% highlight shell %}
sudo sh -c 'echo "AllowGroups ssh-allow gapstra-administrator" >> /etc/ssh/sshd_config'
sudo systemctl restart sshd
{% endhighlight %}
