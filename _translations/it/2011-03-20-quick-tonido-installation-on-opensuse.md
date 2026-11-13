---
title: Installazione rapida di Tonido su openSUSE
description: "Guida passo passo per installare la piattaforma di cloud personale Tonido su openSUSE usando alien per convertire i pacchetti deb, con script di avvio e configurazione di SuSEfirewall2."
date: 2011-03-20 02:08:33 -0300
permalink: /it/index.php/2011/03/20/quick-tonido-installation-on-opensuse/
lang: it
categories:
  - linux
tags:
  - opensuse
  - tonido
---

Allora, la settimana scorsa ho aggiornato il portatile a openSUSE 11.4 e, purtroppo, questo ha rotto la mia installazione di MoneyManagerEx, perché serviva un pacchetto per questa nuova distro e quello di Packman è attualmente rotto a causa di alcune [modifiche](http://www.mail-archive.com/packman@links2linux.de/msg05268.html) al repo.

Siccome ho un mucchio di spese in attesa di essere inserite nella contabilità, mi serviva urgentemente un'installazione di MMEx funzionante, quindi sono andato sulla sua [homepage](http://www.codelathe.com/mmex/) a cercare l'ultima versione e sistemare il mio [pacchetto](https://build.opensuse.org/package/show?package=moneymanagerex&project=home%3Aciriarte) su OBS, rotto da mesi per colpa della mia pigrizia ¬¬’

Ed è lì che l'ho visto: c'è una versione web di MMEx!!!, e questo è fantastico perché mi permetterebbe di usarlo dal mio nuovo telefono Android senza dover accedere al portatile, “magari è pienamente funzionale dal browser” ho pensato….. Leggendo un po' di più, ho scoperto che faceva parte di una piattaforma cloud chiamata Tonido. Sembrava un sacco di fastidio solo per far girare l'applicazione, ma quando ho scoperto che Tonido ha un'applicazione Android dedicata, mi hanno convinto!.

[Qui](http://www.tonido.com/tonidocloud_what.html) ci sono le opzioni di Tonido, che vanno da un'appliance super figa a un servizio cloud, passando per la propria installazione locale. Dato che ho già un VPS, usare Tonido lì sembra una buona soluzione: non devo dipendere dalla pessima connessione del mio ISP né dal fatto che il desktop resti acceso (la compagnia elettrica locale non è una garanzia).

Il VPS gira con openSUSE 11.3 @i586 (cioè la versione a 32 bit). Tonido non fornisce il codice sorgente né tar generici, quindi lavoriamo con i pacchetti deb per Ubuntu. Come cosa da fare, potrei creare un bel pacchetto pulito su [OBS](https://build.opensuse.org) per automatizzare la procedura che sto per documentare qui; per ora questa è una "documentazione di un hack veloce, sporco se preferisci". Inoltre, nota che questa è un'installazione su server dedicato, non prevede "integrazione con il desktop", che resta fuori.

<!--more-->

Prima di tutto, dobbiamo installare alien, per convertire il pacchetto deb in rpm, da cui estrarremo i file.

{% highlight shell %}
zypper in http://download.opensuse.org/repositories/openSUSE:/11.3:/Contrib/standard/i586/alien-8.80-1.2.i586.rpm
{% endhighlight %}

Questo pacchetto viene dal repository Contrib, zypper si occuperà delle dipendenze per noi. Ora dobbiamo scaricare il pacchetto deb originale.

{% highlight shell %}
vps:~ # mkdir tmp
vps:~/tmp # wget http://www.tonidoid.com/download.php?TonidoSetup_i686.deb
vps:~/tmp # mv download.php?TonidoSetup_i686.deb TonidoSetup_i686.deb
{% endhighlight %}

Faremo questa conversione per estrarre i file: deb -> rpm -> cpio

{% highlight shell %}
vps:~/tmp # alien -r TonidoSetup_i686.deb
vps:~/tmp # mkdir extracted
vps:~/tmp # cd extracted
vps:~/tmp/extracted # rpm2cpio ../tonido-2.26.0.13504-2.i386.rpm |cpio -idmv
{% endhighlight %}

La procedura estrarrà tutti i file in ~/tmp/extracted; spostiamo i file in un posto appropriato e puliamo gli avanzi…

{% highlight shell %}
vps:~/tmp/extracted # mv usr/local/tonido /opt
vps:~/tmp/extracted # cd
vps:~ # rm -rf tmp
{% endhighlight %}

Lo script di avvio incluso è /opt/tonido/tonido.sh; ho cambiato la posizione di alcuni file per rendere le cose più “standard”. Ecco un diff con le modifiche (chiedi a google come applicare una patch)

{% highlight diff %}
--- tonido.sh.orig      2011-03-20 01:51:26.000000000 -0300
+++ tonido.sh   2011-03-20 01:52:52.000000000 -0300
@@ -11,9 +11,9 @@ PATH=/usr/local/sbin:/usr/local/bin:/sbi
NAME=tonidoconsole
USER=`whoami`
DESC="Tonido Service"
-TONIDODIR=`echo /usr/local/tonido/`
-PIDFILE=/tmp/tonido_$USER.pid
-LOGFILE=/tmp/tonido_$USER.log
+TONIDODIR=`echo /opt/tonido/`
+PIDFILE=/var/run/tonido.pid
+LOGFILE=/var/log/tonido.log

# Gracefully exit if the package has been removed.
test -x $TONIDODIR/tonidoconsole || exit 0
{% endhighlight %}

Passo successivo, sistemare le dipendenze. Se stai installando Tonido su un'altra distro, dovresti controllare con `ldd /etc/tonido/tonidoconsole` quali sono le librerie mancanti; nel mio caso questo ha risolto le dipendenze:

{% highlight shell %}
zypper in libopenssl0_9_8 mozilla-nss libpng12-0
{% endhighlight %}

Ci serve uno script di avvio. Ho fatto una copia veloce (leggi: pigra) di /etc/init.d/skeleton. Questo è il risultato con i commenti originali tolti, per poterlo copiare qui; sentiti libero di creare una sostituzione ordinata e condividerla!! (prima modifica possibile: far girare il servizio con un utente non root, se per te è un requisito)

{% highlight shell %}
#!/bin/sh
######
# Quick-Lazy startup script for Tonido
# Ciro Iriarte
# 2011-03-20 - v0.01
######
### BEGIN INIT INFO
# Provides:          tonido
# Required-Start:    $network $syslog $remote_fs
# Should-Start:      $named $syslog $time
# Required-Stop:     $network $syslog
# Should-Stop:       $named $syslog $time
# Default-Start:     3 5
# Default-Stop:      0 1 2 6
# Short-Description: Tonido Server
# Description:       Start Tonido to provide personal cloud
### END INIT INFO

TONIDO_SH=/opt/tonido/tonido.sh
TONIDO_BIN=/opt/tonido/tonidoconsole
test -x $TONIDO_SH || { echo "$TONIDO_SH not installed";
if [ "$1" = "stop" ]; then exit 0;
else exit 5; fi; }

. /etc/rc.status

rc_reset

case "$1" in
start)
$TONIDO_SH start
rc_status -v
;;
stop)
$TONIDO_SH stop
rc_status -v
;;
restart)
$TONIDO_SH restart
rc_status
;;
status)
echo -n "Checking for service Tonido "
/sbin/checkproc $TONIDO_BIN
rc_status -v
;;
*)
echo "Usage: $0 {start|stop|status|restart}"
exit 1
;;
esac
rc_exit
{% endhighlight %}

Va creato come /etc/init.d/tonido; non dimenticare il link di gestione e di abilitare il servizio per l'avvio automatico.

{% highlight shell %}
ln -s /etc/init.d/tonido /usr/sbin/rctonido
chkconfig tonido on
{% endhighlight %}

Avvia il servizio

{% highlight shell %}
rctonido start
{% endhighlight %}

Per poter gestire il servizio da remoto, dobbiamo modificare il file ~/tonido/data/configex.xml e abilitare l'amministrazione remota. Imposta value=1 nel parametro RemoteAdmin (scusate, a quanto pare qui non posso pubblicare XML)

Riavvia il servizio per fargli rileggere la configurazione

{% highlight shell %}
rctonido restart
{% endhighlight %}

Se tutto è andato bene, dovresti poter accedere a Tonido su http://server.domain.com:10001.

## Configurazione del firewall {#firewall-configuration}

Se hai un server pubblico, DEVE avere un firewall. Questi sono i passi per configurare SuSEfirewall2.

1. Crea il file /etc/sysconfig/SuSEfirewall2.d/services/tonido (file di regole) e inserisci quanto segue:

{% highlight shell %}
## Name: Tonido
## Description: Opens ports for Tonido server

# space separated list of allowed TCP ports
TCP="10001"

# space separated list of allowed UDP ports
UDP=""

# space separated list of allowed RPC services
RPC=""

# space separated list of allowed IP protocols
IP=""

# space separated list of allowed UDP broadcast ports
BROADCAST=""
{% endhighlight %}

2. Modifica /etc/sysconfig/SuSEfirewall2 e aggiungi “tonido” al parametro `FW_CONFIGURATIONS_EXT`, così:

{% highlight shell %}
FW_CONFIGURATIONS_EXT="apache2 apache2-ssl bind gts mysql sshd tomcat rsync-server tonido"
{% endhighlight %}

3. Riavvia il firewall

{% highlight shell %}
rcSuSEfirewall2 restart
{% endhighlight %}

Buon divertimento!!
