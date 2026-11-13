---
title: "Compilare nrpe su HPUX 11.31"
description: "Guida alla compilazione di NRPE con --enable-command-args su HP-UX 11.31, con il workaround per i TCP wrappers, la patch di nrpe.c, i passi di build e uno script di init personalizzato."
date: 2010-05-11 16:20:32 -0400
permalink: /it/index.php/2010/05/11/compiling-nrpe-in-hpux-11-31-2/
lang: it
categories:
  - monitoring
tags:
  - nagios
  - hpux
---

Ok, ci sono arrivati i nuovi server HP rx8640 con HPUX 11.31 e dovevamo monitorarli con nagios. Siccome check_by_ssh si è rivelato molto più lento di NRPE+SSL sui nostri vecchi server Solaris, abbiamo stabilito come policy che ogni server sotto il nostro controllo vada monitorato con NRPE.

Ho scoperto che [qualcuno ](http://www.mayoxide.com/naghpux/)aveva già fatto il lavoro sporco di compilarlo e aveva persino creato un depot aggiornato (pacchetto software, nel linguaggio di HPUX) che funziona con 11.31. Però ha un paio di svantaggi: gira tramite inetd, che non è pratico quando si fanno tanti controlli frequenti, ed è compilato senza "--enable-command-args", e quest'ultimo punto lo rende inutile per le nostre esigenze.

Usando le note di build di Olivier, leggermente modificate, ho compilato NRPE con "--enable-command-args" e ho creato uno script per avviarlo come servizio standalone invece di usare inetd.

<!--more-->

Ecco il procedimento:

## **Nota sui TCP Wrappers** {#tcp-wrappers-note}

Secondo le note di Olivier, lui ha usato i sorgenti di tcpwrapper inclusi con SSHD (sarà Openssh?) che si trovano in /opt/ssh/src/tcp\_wrappers\_7.6-ipv6.4. Per poterlo compilare ho dovuto modificare il Makefile, aggiungendo “-DUSE\_GETDOMAIN” alla definizione della macro BUGS. Altrimenti ottenevo il seguente errore:

{% highlight shell %}
/usr/ccs/bin/ld: Unsatisfied symbols: yp_get_default_domain (code)
{% endhighlight %}

Procedura:

{% highlight shell %}
vi Makefile <-- add "-DUSE_GETDOMAIN" to BUGS macro definition
make REAL_DAEMON_DIR=/tmp hpux
ls -l libwrap.a
{% endhighlight %}

Il fatto è che non ha funzionato…. Dopo averlo compilato e aver usato il libwrap.a generato in fase di compilazione di NRPE, ottenevo:

{% highlight shell %}
-------------
utils.c:
ld: Unsatisfied symbol "fromhost" in file nrpe.o
1 errors.
*** Error exit code 1
Stop.
*** Error exit code 1
Stop.
-------------
{% endhighlight %}

Tornando al libwrap standard di HPUX, mi è bastato definire in nrpe.c una variabile che gli mancava (rfc931\_timeout)

## **Patch/modifica di NRPE** {#patchingmodifying-nrpe}

{% highlight shell %}
tar xvf nrpe-2.12.tar
cd nrpe-2.12
vi src/nrpe.c

/* Add syslog facilities that are missing in HPUX */
#define LOG_AUTHPRIV (10<<3) /* security/authorization messages (private) */
#define LOG_FTP (11<<3) /* ftp daemon */
/* Adding variable missing in libwrap */
int rfc931_timeout=15;
{% endhighlight %}

## **Configurazione di NRPE** {#nrpe-configuration}

{% highlight shell %}
PATH="$(cat /etc/PATH):/usr/local/bin" ./configure --prefix=/opt/nagios \
   --with-ssl-inc=/opt/openssl/include --with-ssl-lib=/opt/openssl/lib/hpux32 \
   --enable-command-args
{% endhighlight %}

## **Compilazione e installazione** {#compilation--installation}

{% highlight shell %}
make
make install
mkdir /opt/nagios/etc
cp sample-config/nrpe.cfg /opt/nagios/etc/
{% endhighlight %}

## **Script di init** {#init-script}

Ho creato uno script di init per avviare NRPE come servizio, ma a quanto pare wordpress non permette di caricare file arbitrari. Lo caricherò appena possibile.

Aggiornamento: Dato che non riesco a pubblicare file, dovrò includere lo script direttamente qui…. Perché funzioni servono due file, uno per “abilitare” il servizio e lo script di controllo.

/etc/rc.config.d/nrpe

{% highlight shell %}
# Nagios Remote Plugin Executor 
ENABLE_NRPE=1
{% endhighlight %}

/sbin/init.d/nrpe

{% highlight shell %}
#!/usr/bin/bash
# Ciro Iriarte - May 5th, 2010
# some parts taken from SuSE's NRPE init script and xntpd init from HPUX

if [ -f /etc/rc.config ] ; then
        . /etc/rc.config
else
        echo "ERROR: /etc/rc.config defaults file MISSING"
fi

rval=0
set_return() {
        x=$?
        if [ $x -ne 0 ]; then
                echo "EXIT CODE: $x"
                rval=1  # always 1 so that 2 can be used for other reasons
        fi
}

NRPE_BIN=/opt/nagios/bin/nrpe
test -x $NRPE_BIN || { echo "$NRPE_BIN not installed";
        if [ "$1" = "stop" ]; then exit 0;
        else exit 5; fi; }

# Check for existence of needed config file and read it
NRPE_CONFIG=/opt/nagios/etc/nrpe.cfg
test -r $NRPE_CONFIG || { echo "$NRPE_CONFIG not existing";
        if [ "$1" = "stop" ]; then exit 0;
        else exit 6; fi; }

case "$1" in
        start_msg)
                echo -n "Starting Nagios NRPE "
        ;;
        stop_msg)
                echo -n "Shutting down Nagios NRPE "
        ;;
        start)
                if [ $ENABLE_NRPE -eq 1 ]
                then
                        $NRPE_BIN -c $NRPE_CONFIG -d
                        set_return
                        ## $0 start_msg
                        ##if [ $rval -eq 0 ];then echo -e "\t\t[ OK ]";else echo -e "\t\t[ ERR ]";fi 
                else
                        rval=2
                fi
        ;;
        stop)
                if [ $ENABLE_NRPE -ne 1 ]
                then
                        rval=2
                else
                        PID=$(ps -el | awk '( ($NF ~ /nrpe/) && ($4 != mypid) && ($5 != mypid)) { print $4 }' mypid=$$)
                        ##$0 stop_msg
                        if [[ -n $PID ]];then
                                if kill $PID 2/dev/null; then
                                        echo -e "\tService stopped"
                                else
                                        if [ $(ps -fp $PID|grep -v COMMAND|wc -l) -gt 0 ]
                                        then
                                                set_return
                                                ##echo -e "\t\t[ ERR ]"
                                                echo -e "\tCouldn't stop NRPE"
                                        fi
                                fi
                        else
                                set_return
                                ##echo -e "\t\t[ ERR ]"
                                echo -e "\tUnable to stop NRPE, cannot find PID"
                        fi
                fi
        ;;
        restart)
                $0 stop
                $0 start
        ;;
        *)
                echo "Usage: $0 {start|stop|restart}"
                rval=1
        ;;
esac
exit $rval
{% endhighlight %}

Dopo aver creato quei file dovrai creare dei link allo script di controllo per poter avviare e fermare il servizio all'avvio e allo spegnimento

{% highlight shell %}
/sbin/rc1.d/K500nrpe -/sbin/init.d/nrpe
/sbin/rc3.d/S999nrpe -/sbin/init.d/nrpe
{% endhighlight %}

Questi erano i pezzi mancanti…
