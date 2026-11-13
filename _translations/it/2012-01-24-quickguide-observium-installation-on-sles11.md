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

{% highlight shell %}
zypper ar -f http://download.opensuse.org/repositories/network:/utilities/SLE_11_SP1 network:utilities
{% endhighlight %}

*# Installazione dei pacchetti*

{% highlight shell %}
zypper in apache2-mod_php5 php5-mysql php5-gd php5-snmp php5-pear net-snmp graphviz-gd graphviz subversion mysql rrdtool fping ImageMagick whois mtr nmap ipmitool
{% endhighlight %}

*# Moduli aggiuntivi tramite PEAR*

{% highlight shell %}
pear install Net_IPv6
pear install Net_IPv4
{% endhighlight %}

*# Per monitorare VM tramite libvirt*

{% highlight shell %}
zypper in libvirt
{% endhighlight %}

*# Checkout di Observium da SVN*

{% highlight shell %}
cd /opt
svn co http://www.observium.org/svn/observer/trunk observium
{% endhighlight %}

**Database**

*# Creazione di DB e utente*

{% highlight text %}
mysql> create database observium;
mysql> grant all privileges on observium.* to 'observium'@'localhost'
    -> identified by '<pass>';
{% endhighlight %}

*# Creazione dello schema*

{% highlight shell %}
cd observium
mysql -u observium -p observium < database-schema.sql
{% endhighlight %}

*# Aggiornare config.php con i dati di connessione al DB*

{% highlight shell %}
cp config.php{.default,}
vi config.php
{% endhighlight %}

*# Aggiornamenti dello schema*

{% highlight shell %}
for F in database-update*;do scripts/update-sql.php $F;done
{% endhighlight %}

*# Creazione delle directory per RRD e grafici*

{% highlight shell %}
mkdir graphs rrd
chown wwwrun: graphs/ rrd/
{% endhighlight %}

**PERCORSI**

*# fping*

{% highlight shell %}
vi config.php
{% endhighlight %}

{% highlight php %}
$config['fping'] = "/usr/sbin/fping";
{% endhighlight %}

**Apache**

*# Abilitare Mod Rewrite*

{% highlight shell %}
a2enmod rewrite
{% endhighlight %}

*# Configurazione del vhost di apache*

{% highlight shell %}
vi /etc/apache2/vhosts.d/observium.conf
{% endhighlight %}

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


*# Directory di destinazione dei log*

{% highlight shell %}
mkdir /opt/observium/logs/
chown wwwrun: /opt/observium/logs/
{% endhighlight %}

*# Avvio*

{% highlight shell %}
rcapache2 start
chkconfig apache2 on
{% endhighlight %}

*# Utenti (in produzione è meglio configurare LDAP)*

*# Amministratori, livello 10*

{% highlight shell %}
/opt/observium/adduser.php user1 pass 10
{% endhighlight %}

**Dispositivi**

*# Aggiungere nuovi dispositivi*

{% highlight shell %}
cd /opt/observium/ && ./addhost.php <hostname> <community> v2c
{% endhighlight %}

*# Discovery iniziale + raccolta dati*

{% highlight shell %}
./discovery.php -h all
./poller.php -h all
{% endhighlight %}

*# Abilitare la raccolta dati tramite cron*

{% highlight shell %}
vi /etc/cron.d/observium
{% endhighlight %}

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


**Ottimizzazione delle prestazioni**

*# Installare XCache, ricostruire il pacchetto da OBS perché non esiste per SP1*

{% highlight shell %}
mkdir ~/tmp
cd ~/tmp
wget http://download.opensuse.org/repositories/server:/php:/extensions/SLE_11/src/php5-xcache-1.3.2-2.1.src.rpm
rpmbuild --rebuild php5-xcache-1.3.2-2.1.src.rpm
{% endhighlight %}

*# Installare il risultato del comando precedente*

*# Riavviare apache*

{% highlight shell %}
rcapache2 restart
{% endhighlight %}

Questo è tutto, la stessa procedura dovrebbe funzionare con openSUSE, a patto di usare i repository giusti…
