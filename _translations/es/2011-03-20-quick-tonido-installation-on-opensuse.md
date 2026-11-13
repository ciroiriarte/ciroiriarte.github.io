---
title: Instalación rápida de Tonido en openSUSE
description: "Guía paso a paso para instalar la plataforma de nube personal Tonido en openSUSE usando alien para convertir paquetes deb, con script de inicio y configuración de SuSEfirewall2."
date: 2011-03-20 02:08:33 -0300
permalink: /es/index.php/2011/03/20/quick-tonido-installation-on-opensuse/
lang: es
categories:
  - linux
tags:
  - opensuse
  - tonido
---

Bueno, la semana pasada actualicé mi laptop a openSUSE 11.4 y eso, por desgracia, rompió mi instalación de MoneyManagerEx, porque necesitaba un paquete para esta nueva distro y el de Packman está roto por unos [cambios](http://www.mail-archive.com/packman@links2linux.de/msg05268.html) en el repo.

Como tengo una pila de gastos pendientes de cargar en mi contabilidad, me urgía encontrar una instalación de MMEx que funcionara, así que fui a su [página](http://www.codelathe.com/mmex/) a buscar la última versión y arreglar mi [paquete](https://build.opensuse.org/package/show?package=moneymanagerex&project=home%3Aciriarte) en OBS, que lleva meses roto por mi flojera ¬¬’

Ahí fue donde lo vi: ¡¡¡hay una versión web de MMEx!!!, y eso es genial porque me permitiría usarlo desde mi nuevo teléfono Android sin necesidad de acceder a mi laptop, “quizás sea totalmente funcional en su navegador” pensé….. Leyendo un poco más, descubrí que era parte de una plataforma de nube llamada Tonido. Eso sonaba a demasiado lío solo para correr la aplicación, pero cuando vi que Tonido tiene una aplicación Android dedicada, ¡quedé vendido!.

[Aquí](http://www.tonido.com/tonidocloud_what.html) están las opciones de Tonido, que van desde un appliance súper cool hasta un servicio en la nube, pasando por tu propia instalación local. Como ya tengo un VPS, usar Tonido en él suena como una buena solución, no tengo que depender de la porquería de conexión de mi ISP ni de que mi equipo de escritorio esté encendido (la compañía eléctrica local no es garantía de nada).

El VPS corre openSUSE 11.3 @i586 (o sea, la versión de 32 bits). Tonido no provee código fuente ni tarballs genéricos, así que trabajamos con paquetes deb para Ubuntu. Como tarea pendiente, quizás arme un paquete limpio y prolijo en [OBS](https://build.opensuse.org) para automatizar el procedimiento que voy a documentar acá; por ahora esta es una "documentación de un hack rápido, sucio si quieres". Además, ten en cuenta que esta es una instalación de servidor dedicado, no contempla "integración con el escritorio", que queda fuera.

<!--more-->

Primero, necesitamos instalar alien, para convertir el paquete deb a rpm, de donde extraeremos los archivos.

{% highlight shell %}
zypper in http://download.opensuse.org/repositories/openSUSE:/11.3:/Contrib/standard/i586/alien-8.80-1.2.i586.rpm
{% endhighlight %}

Este paquete viene del repositorio Contrib, zypper se encargará de las dependencias por nosotros. Ahora, debemos descargar el paquete deb original.

{% highlight shell %}
vps:~ # mkdir tmp
vps:~/tmp # wget http://www.tonidoid.com/download.php?TonidoSetup_i686.deb
vps:~/tmp # mv download.php?TonidoSetup_i686.deb TonidoSetup_i686.deb
{% endhighlight %}

Haremos esta conversión para extraer los archivos: deb -> rpm -> cpio

{% highlight shell %}
vps:~/tmp # alien -r TonidoSetup_i686.deb
vps:~/tmp # mkdir extracted
vps:~/tmp # cd extracted
vps:~/tmp/extracted # rpm2cpio ../tonido-2.26.0.13504-2.i386.rpm |cpio -idmv
{% endhighlight %}

El procedimiento extraerá todos los archivos a ~/tmp/extracted, vamos a reubicar los archivos en un lugar apropiado y limpiar lo que sobra…

{% highlight shell %}
vps:~/tmp/extracted # mv usr/local/tonido /opt
vps:~/tmp/extracted # cd
vps:~ # rm -rf tmp
{% endhighlight %}

El script de inicio incluido es /opt/tonido/tonido.sh, le hice algunos cambios a la ubicación de ciertos archivos para que todo sea más “estándar”. Aquí hay un diff con los cambios (pregúntale a google cómo aplicar un patch)

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

Siguiente paso, arreglar las dependencias. Si estás instalando Tonido en otra distro, deberías revisar con `ldd /etc/tonido/tonidoconsole` cuáles son las bibliotecas faltantes; en mi caso esto resolvió las dependencias:

{% highlight shell %}
zypper in libopenssl0_9_8 mozilla-nss libpng12-0
{% endhighlight %}

Necesitamos un script de inicio. Hice una copia rápida (léase floja) de /etc/init.d/skeleton. Este es el resultado con los comentarios originales eliminados, para poder copiarlo aquí; siéntete libre de crear un reemplazo prolijo y compartirlo!! (primer cambio posible: correr el servicio con un usuario no root si es un requisito para ti)

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

Debe crearse como /etc/init.d/tonido, no olvides el link de administración y habilitar el servicio para el inicio automático.

{% highlight shell %}
ln -s /etc/init.d/tonido /usr/sbin/rctonido
chkconfig tonido on
{% endhighlight %}

Inicia el servicio

{% highlight shell %}
rctonido start
{% endhighlight %}

Para poder administrar el servicio remotamente, debemos modificar el archivo ~/tonido/data/configex.xml y habilitar la administración remota. Pon value=1 en el parámetro RemoteAdmin (perdón, al parecer no puedo publicar XML aquí)

Reinicia el servicio para que relea la configuración

{% highlight shell %}
rctonido restart
{% endhighlight %}

Si todo salió bien, deberías poder acceder a Tonido en http://server.domain.com:10001.

## Configuración del firewall {#firewall-configuration}

Si tienes un servidor público, DEBE tener un firewall. Estos son los pasos para configurar SuSEfirewall2.

1. Crea el archivo /etc/sysconfig/SuSEfirewall2.d/services/tonido (archivo de reglas) y pon en él lo siguiente:

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

2. Edita /etc/sysconfig/SuSEfirewall2, y agrega “tonido” al parámetro `FW_CONFIGURATIONS_EXT`, así:

{% highlight shell %}
FW_CONFIGURATIONS_EXT="apache2 apache2-ssl bind gts mysql sshd tomcat rsync-server tonido"
{% endhighlight %}

3. Reinicia el firewall

{% highlight shell %}
rcSuSEfirewall2 restart
{% endhighlight %}

¡¡A divertirse!!
