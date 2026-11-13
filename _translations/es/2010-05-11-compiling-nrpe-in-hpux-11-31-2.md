---
title: "Compilando nrpe en HPUX 11.31"
description: "Guía para compilar NRPE con --enable-command-args en HP-UX 11.31, incluyendo el workaround de TCP wrappers, el parche de nrpe.c, los pasos de compilación y un script de init propio."
date: 2010-05-11 16:20:32 -0400
permalink: /es/index.php/2010/05/11/compiling-nrpe-in-hpux-11-31-2/
lang: es
categories:
  - monitoring
tags:
  - nagios
  - hpux
---

Bueno, nos llegaron los servidores HP rx8640 nuevos con HPUX 11.31 y había que monitorearlos con nagios. Como check_by_ssh resultó ser mucho más lento que NRPE+SSL en nuestros antiguos servidores Solaris, definimos como política que todo servidor bajo nuestro control se monitoree usando NRPE.

Encontré que [alguien ](http://www.mayoxide.com/naghpux/)ya hizo el trabajo sucio de compilarlo e incluso creó un depot actual (paquete de software en términos de HPUX) que funciona con 11.31. Tiene un par de inconvenientes, eso sí: corre usando inetd, lo cual no es práctico cuando haces muchos chequeos frecuentes, y está compilado sin "--enable-command-args", y esto último lo hace inútil para lo que necesitamos.

Usando las notas de compilación de Olivier, ligeramente modificadas, compilé NRPE con "--enable-command-args" y creé un script para iniciarlo como servicio independiente en lugar de usar inetd.

<!--more-->

Este es el proceso:

## **Nota sobre TCP Wrappers** {#tcp-wrappers-note}

Según las notas de Olivier, él usó el código fuente de tcpwrapper incluido con SSHD (¿será Openssh?) ubicado en /opt/ssh/src/tcp\_wrappers\_7.6-ipv6.4. Para poder compilarlo, tuve que modificar el Makefile, agregando “-DUSE\_GETDOMAIN” a la definición de la macro BUGS. De lo contrario, obtenía el siguiente error:

{% highlight shell %}
/usr/ccs/bin/ld: Unsatisfied symbols: yp_get_default_domain (code)
{% endhighlight %}

Procedimiento:

{% highlight shell %}
vi Makefile <-- add "-DUSE_GETDOMAIN" to BUGS macro definition
make REAL_DAEMON_DIR=/tmp hpux
ls -l libwrap.a
{% endhighlight %}

El asunto es que no funcionó…. Después de compilarlo y usar el libwrap.a generado al compilar NRPE, obtenía:

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

Volviendo al libwrap estándar de HPUX, solo necesité definir en nrpe.c una variable que le faltaba (rfc931\_timeout)

## **Parchear/modificar NRPE** {#patchingmodifying-nrpe}

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

## **Configuración de NRPE** {#nrpe-configuration}

{% highlight shell %}
PATH="$(cat /etc/PATH):/usr/local/bin" ./configure --prefix=/opt/nagios \
   --with-ssl-inc=/opt/openssl/include --with-ssl-lib=/opt/openssl/lib/hpux32 \
   --enable-command-args
{% endhighlight %}

## **Compilación e instalación** {#compilation--installation}

{% highlight shell %}
make
make install
mkdir /opt/nagios/etc
cp sample-config/nrpe.cfg /opt/nagios/etc/
{% endhighlight %}

## **Script de init** {#init-script}

Creé un script de init para iniciar NRPE como servicio, pero aparentemente wordpress no permite subir archivos arbitrarios. Lo subiré apenas pueda.

Actualización: Como no puedo publicar archivos, tendré que incluir el script en el texto…. Para que esto funcione necesitas dos archivos, uno para “habilitar” el servicio y el script de control.

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

Después de crear esos archivos tendrás que crear enlaces al script de control para poder iniciar y detener el servicio en el arranque y el apagado

{% highlight shell %}
/sbin/rc1.d/K500nrpe -/sbin/init.d/nrpe
/sbin/rc3.d/S999nrpe -/sbin/init.d/nrpe
{% endhighlight %}

Esas eran las piezas que faltaban…
