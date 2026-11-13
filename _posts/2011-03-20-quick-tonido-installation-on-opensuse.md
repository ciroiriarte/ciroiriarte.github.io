---
title: Quick Tonido installation on openSUSE
description: "Step-by-step guide for installing Tonido personal cloud platform on openSUSE using alien to convert deb packages, with init script and SuSEfirewall2 configuration."
date: 2011-03-20 02:08:33 -0300
author: Ciro Iriarte
permalink: /index.php/2011/03/20/quick-tonido-installation-on-opensuse/
lang: en
categories:
  - linux
tags:
  - opensuse
  - tonido
---

Ok, last week I updated my laptop to openSUSE 11.4, that, unluckily, broke my MoneyManagerEx installation as I needed a package for this new distro and the one from Packman is currently broken because of some repo [changes](http://www.mail-archive.com/packman@links2linux.de/msg05268.html).

Because I have a pile of expenses pending to be added to my accounting, I was urged to find a working MMEx installation, so I went to it’s [homepage](http://www.codelathe.com/mmex/) to look for latest version and fix my OBS [package](https://build.opensuse.org/package/show?package=moneymanagerex&project=home%3Aciriarte) that has been broken for months because of my lazyness ¬¬’

Then, that’s were I saw it, there’s a web version of MMEx!!!, and that’s great as it would allow me to use it from my new Android phone without the need to access to my laptop, “maybe it’ll be fully functional on its browser” I thought….. Reading a little more, I found out that it was part of some cloud platform called Tonido. That sounded like a lot of hassle just for running the application, but when I found out that Tonido has a dedicated Android application, I was sold!.

[Here](http://www.tonido.com/tonidocloud_what.html) are the Tonido options, ranging from super cool appliance to a cloud service, passing by your own local installation. As I already have a VPS, using Tonido on it sounds like a nice solution, I don’t have to rely on my ISP crappy conection or my desktop uptime (local electricity company is no warranty).

The VPS is running openSUSE 11.3 @i586 (that is, 32bit version). Tonido doesn't provide source code or generic tar files, so we are working with deb packages for Ubuntu. As a pending task, I might make a nice clean package on [OBS](https://build.opensuse.org) to automate the procedure I'm going to document here, for the time being this is a "quick, dirty if you like, hack documentation". Also, note this is a dedicated server installation, it won't contemplate "desktop integration" as desktop integration will be left outside.

<!--more-->

First, we need to install alien, to allow us to convert the deb package to rpm from were we’ll extract the files.

{% highlight shell %}
zypper in http://download.opensuse.org/repositories/openSUSE:/11.3:/Contrib/standard/i586/alien-8.80-1.2.i586.rpm
{% endhighlight %}

This package comes from Contrib repository, zypper will take care of the dependencies for us. Now, we should download original deb package.

{% highlight shell %}
vps:~ # mkdir tmp
vps:~/tmp # wget http://www.tonidoid.com/download.php?TonidoSetup_i686.deb
vps:~/tmp # mv download.php?TonidoSetup_i686.deb TonidoSetup_i686.deb
{% endhighlight %}

We'll make this conversion to extract the files: deb -> rpm -> cpio

{% highlight shell %}
vps:~/tmp # alien -r TonidoSetup_i686.deb
vps:~/tmp # mkdir extracted
vps:~/tmp # cd extracted
vps:~/tmp/extracted # rpm2cpio ../tonido-2.26.0.13504-2.i386.rpm |cpio -idmv
{% endhighlight %}

The procedure will extract all files to ~/tmp/extracted, we’ll relocate the files to an appropriated place and clean the leftover…

{% highlight shell %}
vps:~/tmp/extracted # mv usr/local/tonido /opt
vps:~/tmp/extracted # cd
vps:~ # rm -rf tmp
{% endhighlight %}

The included startup script is /opt/tonido/tonido.sh, I made some changes to the location of some files to make things more “standard”. Here is a diff with the changes (ask google how to apply a patch)

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

Next step, to fix dependencies. If you’re installing Tonido on a different distro, you should check with `ldd /etc/tonido/tonidoconsole` what are the missing libraries, in my case this solved the dependencies:

{% highlight shell %}
zypper in libopenssl0_9_8 mozilla-nss libpng12-0
{% endhighlight %}

We need a startup script. I created a quick (read lazy) copy of /etc/init.d/skeleton. This is the result with the original comments stripped out, to be able to copy it here, feel free to create a nice tidy replacement for it and share it!! (first possible change, run the service as a non root user if that’s a requirement for you)

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

It should be created as /etc/init.d/tonido, don’t forget the management link and enable the service for automatic startup.

{% highlight shell %}
ln -s /etc/init.d/tonido /usr/sbin/rctonido
chkconfig tonido on
{% endhighlight %}

Start the service

{% highlight shell %}
rctonido start
{% endhighlight %}

To be able to run the service remotely, we should change the file ~/tonido/data/configex.xml and enable remote administration. Set value=1 for RemoteAdmin parameter (sorry, can’t post XML here apparently)

Restart the service to reread the configuration

{% highlight shell %}
rctonido restart
{% endhighlight %}

If everything went fine, you should be able to access Tonido at http://server.domain.com:10001.

## Firewall configuration

If you have a public server, it MUST have a firewall. This are the steps to configure SuSEfirewall2.

1. Create the file /etc/sysconfig/SuSEfirewall2.d/services/tonido (rule file) and put in it the following:

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

2. Edit /etc/sysconfig/SuSEfirewall2, and add “tonido” to the `FW_CONFIGURATIONS_EXT` parameter, like this:

{% highlight shell %}
FW_CONFIGURATIONS_EXT="apache2 apache2-ssl bind gts mysql sshd tomcat rsync-server tonido"
{% endhighlight %}

3. Restart the firewall

{% highlight shell %}
rcSuSEfirewall2 restart
{% endhighlight %}

Have fun!!
