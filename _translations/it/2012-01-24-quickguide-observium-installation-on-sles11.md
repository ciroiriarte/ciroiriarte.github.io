---
title: "Guida rapida: installazione di Observium su SLES11"
description: "Guida rapida all'installazione di Observium, monitoraggio di rete, su SLES11: Apache/MySQL/PHP/rrdtool, database, vhost, job cron e ottimizzazione di XCache."
date: 2012-01-24 15:57:34 -0300
permalink: /it/index.php/2012/01/24/quickguide-observium-installation-on-sles11/
lang: it
categories:
  - monitoring
tags:
  - observium
  - sles
---

Mi sono imbattuto in un ottimo strumento per raccogliere dati chiamato [Observium](http://www.observium.org), funziona con mysql+php+rrdtool raccogliendo dati via SNMP. Ecco i miei appunti basati sulla guida originale per Debian+SVN.

<!--more-->

**Repository iniziali**

SLES11 + SLE11-SDK + Updates

**Prerequisiti**

*# Repository aggiuntivi*

> zypper ar -f http://download.opensuse.org/repositories/network:/utilities/SLE_11_SP1 network:utilities

*# Installazione dei pacchetti*

> zypper in apache2-mod_php5 php5-mysql php5-gd php5-snmp php5-pear net-snmp graphviz-gd graphviz subversion mysql rrdtool fping ImageMagick whois mtr nmap ipmitool

*# Moduli aggiuntivi tramite PEAR*

> pear install Net_IPv6
> pear install Net_IPv4

*# Per monitorare VM tramite libvirt*

> zypper in libvirt

*# Checkout di Observium da SVN*

> cd /opt
> svn co http://www.observium.org/svn/observer/trunk observium

**Database**

*# Creazione di DB e utente*

> mysql> create database observium;

> mysql> grant all privileges on observium.* to 'observium'@'localhost' -> identified by '<pass>';

*# Creazione dello schema*

> cd observium

> mysql -u observium -p observium < database-schema.sql

*# Aggiornare config.php con i dati di connessione al DB*

> cp config.php{.default,}

> vi config.php

*# Aggiornamenti dello schema*

> for F in database-update*;do scripts/update-sql.php $F;done

*# Creazione delle directory per RRD e grafici*

> mkdir graphs rrd
> chown wwwrun: graphs/ rrd/

**PERCORSI**

*# fping*

> vi config.php

> ---

> $config['fping'] = "/usr/sbin/fping";

> ---

**Apache**

*# Abilitare Mod Rewrite*

> a2enmod rewrite

*# Configurazione del vhost di apache*

> vi /etc/apache2/vhosts.d/observium.conf

> ---

```apache
<VirtualHost *:80>
DocumentRoot /opt/observium/html/
ServerName observium.<domain>
CustomLog /opt/observium/logs/access_log combined
ErrorLog /opt/observium/logs/error_log
<Directory "/opt/observium/html/">
AllowOverride All
Options FollowSymLinks MultiViews
Order allow,deny
Allow from all
</Directory>
</VirtualHost>
```

> ---

*# Directory di destinazione dei log*

> mkdir /opt/observium/logs/

> chown wwwrun: /opt/observium/logs/

*# Avvio*

> rcapache2 start
> chkconfig apache2 on

*# Utenti (in produzione è meglio configurare LDAP)*

*# Amministratori, livello 10*

> /opt/observium/adduser.php user1 pass 10

**Dispositivi**

*# Aggiungere nuovi dispositivi*

> cd /opt/observium/ && ./addhost.php <hostname> <community> v2c

*# Discovery iniziale + raccolta dati*

> ./discovery.php -h all

> ./poller.php -h all

*# Abilitare la raccolta dati tramite cron*

> vi /etc/cron.d/observium

> ---

```
33 */6 * * * root cd /opt/observium/ && ./discovery.php -h all >> /dev/null 2>&1
*/5 * * * * root cd /opt/observium/ && ./discovery.php -h new >> /dev/null 2>&1
*/5 * * * * root cd /opt/observium/ && ./poller.php -i 8 -n 0 >> /dev/null 2>&1
*/5 * * * * root cd /opt/observium/ && ./poller.php -i 8 -n 1 >> /dev/null 2>&1
*/5 * * * * root cd /opt/observium/ && ./poller.php -i 8 -n 2 >> /dev/null 2>&1
*/5 * * * * root cd /opt/observium/ && ./poller.php -i 8 -n 3 >> /dev/null 2>&1
*/5 * * * * root cd /opt/observium/ && ./poller.php -i 8 -n 4 >> /dev/null 2>&1
*/5 * * * * root cd /opt/observium/ && ./poller.php -i 8 -n 5 >> /dev/null 2>&1
*/5 * * * * root cd /opt/observium/ && ./poller.php -i 8 -n 6 >> /dev/null 2>&1
*/5 * * * * root cd /opt/observium/ && ./poller.php -i 8 -n 7 >> /dev/null 2>&1
```

> ---

**Ottimizzazione delle prestazioni**

*# Installare XCache, ricostruire il pacchetto da OBS perché non esiste per SP1*

> mkdir ~/tmp
> cd ~/tmp
> wget http://download.opensuse.org/repositories/server:/php:/extensions/SLE_11/src/php5-xcache-1.3.2-2.1.src.rpm
> rpmbuild --rebuild php5-xcache-1.3.2-2.1.src.rpm

*# Installare il risultato del comando precedente*

*# Riavviare apache*

> rcapache2 restart

Questo è tutto, la stessa procedura dovrebbe funzionare con openSUSE, a patto di usare i repository giusti…
