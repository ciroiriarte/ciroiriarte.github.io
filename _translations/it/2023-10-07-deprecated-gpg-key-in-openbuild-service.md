---
title: Chiave GPG deprecata in OpenBuild Service
description: Soluzione rapida per forzare la sostituzione della chiave
date: 2023-10-07 00:00:00 -0300
permalink: /it/homelab/2023/10/07/deprecated-gpg-key-in-openbuild-service.html
lang: it
categories:
  - linux
tags:
  - open-build-service
  - opensuse
  - ubuntu
---

## OpenBuild Service {#openbuild-service}

Quelli di openSuSE hanno costruito una bella soluzione self-service per la creazione di pacchetti Linux, che credo si chiamasse originariamente openSuSE Build Service (OBS). Più tardi è stata rinominata OpenBuild Service per riflettere la capacità di costruire pacchetti per più distro oltre a openSuSE.

Maggiori info: [Wikipedia](https://en.wikipedia.org/wiki/Open_Build_Service)

## Firma GPG {#gpg-signature}

Per proteggere la community di ogni distribuzione Linux, i creatori di ciascuna soluzione di gestione dei pacchetti hanno pensato di firmare con chiavi GPG il contenuto dei repository e i pacchetti. È stata un'idea molto intelligente e molto utile come misura base di igiene/sicurezza.

Questa funzionalità di firma GPG è inclusa in OBS.

## Deprecazione delle chiavi DSA-1024 {#dsa-1024-key-deprecation}

Come molte altre community di packaging software, Ubuntu ha deprecato intorno al 2016 le chiavi GPG basate su DSA-1024, il che significa che apt non accetta più quelle chiavi.

## Il problema {#the-issue}

Nel mio caso, ho creato un sottoprogetto per i pacchetti Ubuntu 22.04. Dato che avevo già un progetto padre con una chiave DSA-1024 ereditata dal nuovo sottoprogetto, tutti i pacchetti sono stati firmati con quella e poi il gestore dei pacchetti si lamentava della chiave senza dare troppe indicazioni sul perché.

{% highlight shell %}
Err:8 http://download.opensuse.org/repositories/home:/ciriarte:/apstra-4.2.0-fix/xUbuntu_22.04  InRelease
  The following signatures were invalid: 8FE63E73E027DE951D5EAFDBA6F3579ABB33D482
Reading package lists... Done
W: GPG error: http://download.opensuse.org/repositories/home:/ciriarte:/apstra-4.2.0-fix/xUbuntu_22.04  InRelease: The following signatures were invalid: 8FE63E73E027DE951D5EAFDBA6F3579ABB33D482
E: The repository 'http://download.opensuse.org/repositories/home:/ciriarte:/apstra-4.2.0-fix/xUbuntu_22.04  InRelease' is not signed.
N: Updating from such a repository can't be done securely, and is therefore disabled by default.
N: See apt-secure(8) manpage for repository creation and user configuration details.
{% endhighlight %}

Di solito vedresti un messaggio che dice che manca la chiave, o che la cipher suite non è accettata, o qualcosa del genere. In questo caso era un generico messaggio "The following signatures were invalid".

Guardando le chiavi pubbliche installate, ho notato che il mio repository usava una chiave dsa1024, mentre tutte le altre usavano rsa4096.

{% highlight shell mark_lines="18" %}
admin@apstra-os-03:~$ sudo apt-key list
[sudo] password for admin:
Warning: apt-key is deprecated. Manage keyring files in trusted.gpg.d
instead (see apt-key(8)).
/etc/apt/trusted.gpg
--------------------
pub   rsa1024 2009-01-26 [SC]
      3AE6 3EC8 2014 45CB 55E6  B1EE DCCB 2270 E771 6B13
uid           [ unknown] Launchpad PPA for Stéphane Graber

pub   rsa4096 2017-02-22 [SCEA]
      9DC8 5822 9FC7 DD38 854A  E2D8 8D81 803C 0EBF CD88
uid           [ unknown] Docker Release (CE deb) <docker@docker.com>
sub   rsa4096 2017-02-22 [S]

/etc/apt/trusted.gpg.d/home_ciriarte_apstra-4.2.0-fix.gpg
---------------------------------------------------------
pub   dsa1024 2008-01-22 [SC] [expires: 2025-12-13]
      8FE6 3E73 E027 DE95 1D5E  AFDB A6F3 579A BB33 D482
uid           [ unknown] home:ciriarte OBS Project
<home:ciriarte@build.opensuse.org>

/etc/apt/trusted.gpg.d/ubuntu-keyring-2012-cdimage.gpg
------------------------------------------------------
pub   rsa4096 2012-05-11 [SC]
      8439 38DF 228D 22F7 B374  2BC0 D94A A3F0 EFE2 1092
uid           [ unknown] Ubuntu CD Image Automatic Signing Key (2012)
<cdimage@ubuntu.com>

/etc/apt/trusted.gpg.d/ubuntu-keyring-2018-archive.gpg
------------------------------------------------------
pub   rsa4096 2018-09-17 [SC]
      F6EC B376 2474 EDA9 D21B  7022 8719 20D1 991B C93C
uid           [ unknown] Ubuntu Archive Automatic Signing Key (2018)
<ftpmaster@ubuntu.com>
{% endhighlight %}

## La soluzione {#the-fix}

Alla fine il colpevole era il vecchio tipo di chiave deprecato (il mio progetto home è stato creato parecchio tempo fa). Non sono riuscito a trovare un modo per creare una nuova chiave GPG nella [web UI](https://build.opensuse.org); o non c'è, o sono io che sono cieco.

Useremo il client/tool CLI di OBS: osc.

Nella man page di osc possiamo trovare:

{% highlight text %}
       signkey
             Manage Project Signing Key

             osc signkey [--create|--delete|--extend] <PROJECT> osc signkey [--notraverse] <PROJECT>

             This command is for managing gpg keys. It shows the public key by default. There is no way to download or upload the private  part  of  a
             key by design.

             However you can create a new own key. You may want to consider to sign the public key with your own existing key.

             If  a  project  has  no  key,  the  key  from upper level project will be used (e.g. when dropping "KDE:KDE4:Community" key, the one from
             "KDE:KDE4" will be used).

             WARNING: THE OLD KEY CANNOT BE RESTORED AFTER USING DELETE OR CREATE

             Usage:
                 osc signkey [ARGS...]

             Options:
                 -h, --help  show this help message and exit
                 --sslcert   fetch SSL certificate instead of GPG key
                 --notraverse
                             don't traverse projects upwards to find key
                 --delete    delete the gpg signing key in this project
                 --extend    extend expiration date of the gpg public key for this
                             project
                 --create    create new gpg signing key for this project
{% endhighlight %}


Su una macchina Linux, devi seguire questa procedura:


{% highlight shell %}

# Install the tool via your favorite package manager
sudo zypper in -y osc

# First execution will ask for OBS credentials
osc

# We query the current key for the repository
osc signkey home:ciriarte:apstra-4.2.0-fix

# We create a new key for the repository
osc signkey --create home:ciriarte:apstra-4.2.0-fix

# We query the new key for the repository (should be different if the creation worked)
osc signkey home:ciriarte:apstra-4.2.0-fix

# We wipe all the binaries to force recreation and resign of the packages with the new key
osc wipebinaries --all home:ciriarte:apstra-4.2.0-fix freeipa
{% endhighlight %}


Sul client, dopo aver reimportato la chiave pubblica, dovresti vedere che non è più dsa1024.

{% highlight shell mark_lines="16" %}
root@apstra-os-03:~# apt-key list
Warning: apt-key is deprecated. Manage keyring files in trusted.gpg.d instead (see apt-key(8)).
/etc/apt/trusted.gpg
--------------------
pub   rsa1024 2009-01-26 [SC]
      3AE6 3EC8 2014 45CB 55E6  B1EE DCCB 2270 E771 6B13
uid           [ unknown] Launchpad PPA for Stéphane Graber

pub   rsa4096 2017-02-22 [SCEA]
      9DC8 5822 9FC7 DD38 854A  E2D8 8D81 803C 0EBF CD88
uid           [ unknown] Docker Release (CE deb) <docker@docker.com>
sub   rsa4096 2017-02-22 [S]

/etc/apt/trusted.gpg.d/home_ciriarte_apstra-4.2.0-fix.gpg
---------------------------------------------------------
pub   rsa4096 2023-10-07 [SC] [expires: 2025-12-15]
      37C6 811B 46C8 134C 5705  8A45 33E6 7F5C 0370 8C89
uid           [ unknown] home:ciriarte:apstra-4.2.0-fix OBS Project <home:ciriarte:apstra-4.2.0-fix@build.opensuse.org>

/etc/apt/trusted.gpg.d/ubuntu-keyring-2012-cdimage.gpg
------------------------------------------------------
pub   rsa4096 2012-05-11 [SC]
{% endhighlight %}
