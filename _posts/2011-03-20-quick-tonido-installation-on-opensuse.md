---
id: 128
title: 'Quick Tonido installation on openSUSE'
date: '2011-03-20T02:08:33-03:00'
author: Ciro Iriarte
layout: post
guid: 'http://cyruspy.wordpress.com/?p=128'
permalink: /index.php/2011/03/20/quick-tonido-installation-on-opensuse/
categories:
    - Linux
    - Projects
tags:
    - MoneyManagerEx
    - openSUSE
    - SuSEfirewall2
    - Tonido
---

Ok, last week I updated my laptop to openSUSE 11.4, that, unluckily, broke my MoneyManagerEx installation as I needed a package for this new distro and the one from Packman is currently broken because of some repo [changes](http://www.mail-archive.com/packman@links2linux.de/msg05268.html).

Because I have a pile of expenses pending to be added to my accounting, I was urged to find a working MMEx installation, so I went to it’s [homepage](http://www.codelathe.com/mmex/) to look for latest version and fix my OBS [package](https://build.opensuse.org/package/show?package=moneymanagerex&project=home%3Aciriarte) that has been broken for months because of my lazyness ¬¬’

Then, that’s were I saw it, there’s a web version of MMEx!!!, and that’s great as it would allow me to use it from my new Android phone without the need to access to my laptop, “maybe it’ll be fully functional on its browser” I thought….. Reading a little more, I found out that it was part of some cloud platform called Tonido. That sounded like a lot of hassle just for running the application, but when I found out that Tonido has a dedicated Android application, I was sold!.

[Here](http://www.tonido.com/tonidocloud_what.html) are the Tonido options, ranging from super cool appliance to a cloud service, passing by your own local installation. As I already have a VPS, using Tonido on it sounds like a nice solution, I don’t have to rely on my ISP crappy conection or my desktop uptime (local electricity company is no warranty).

The VPS is running openSUSE 11.3 @i586 (that is, 32bit version). Tonido doesn’t provide source code or generic tar files, so we are working with deb packages for Ubuntu. As a pending task, I might make a nice clean package on [OBS](https://build.opensuse.org) to automate the procedure I’m going to document here, for the time being this is a “quick, dirty if you like, hack documentation”. Also, note this is a dedicated server installation, it won’t contemplate “desktop integration” as desktop integration will be left outside.

First, we need to install alien, to allow us to convert the deb package to rpm from were we’ll extract the files.

- - - - - -

> `zypper in http://download.opensuse.org/repositories/openSUSE:/11.3:/Contrib/standard/i586/alien-8.80-1.2.i586.rpm`

- - - - - -

This package comes from Contrib repository, zypper will take care of the dependencies for us. Now, we should download original deb package.

- - - - - -

> `vps:~ # mkdir tmp<br></br>vps:~/tmp # wget http://www.tonidoid.com/download.php?TonidoSetup_i686.deb<br></br>vps:~/tmp # mv download.php\?TonidoSetup_i686.deb TonidoSetup_i686.deb`

- - - - - -

We’ll make this conversion to extract the files: deb –&gt; rpm –&gt; cpio

- - - - - -

> `vps:~/tmp # alien -r TonidoSetup_i686.deb<br></br>vps:~/tmp # mkdir extracted<br></br>vps:~/tmp # cd extracted<br></br>vps:~/tmp/extracted # rpm2cpio ../tonido-2.26.0.13504-2.i386.rpm |cpio -idmv`

- - - - - -

The procedure will extract all files to ~/tmp/extracted, we’ll relocate the files to an appropriated place and clean the leftover…

- - - - - -

> `vps:~/tmp/extracted # mv usr/local/tonido /opt<br></br>vps:~/tmp/extracted # cd<br></br>vps:~ # rm -rf tmp<br></br>`

- - - - - -

The included startup script is /opt/tonido/tonido.sh, I made some changes to the location of some files to make things more “standard”. Here is a diff with the changes (ask google how to apply a patch)

- - - - - -

> `--- tonido.sh.orig      2011-03-20 01:51:26.000000000 -0300<br></br>+++ tonido.sh   2011-03-20 01:52:52.000000000 -0300<br></br>@@ -11,9 +11,9 @@ PATH=/usr/local/sbin:/usr/local/bin:/sbi<br></br>NAME=tonidoconsole<br></br>USER=`whoami`<br></br>DESC="Tonido Service"<br></br>-TONIDODIR=`echo /usr/local/tonido/`<br></br>-PIDFILE=/tmp/tonido_$USER.pid<br></br>-LOGFILE=/tmp/tonido_$USER.log<br></br>+TONIDODIR=`echo /opt/tonido/`<br></br>+PIDFILE=/var/run/tonido.pid<br></br>+LOGFILE=/var/log/tonido.log`
> 
> ` ``# Gracefully exit if the package has been removed.<br></br>test -x $TONIDODIR/tonidoconsole || exit 0<br></br>`

- - - - - -

Next step, to fix dependencies. If you’re installing Tonido on a different distro, you should check with `ldd /etc/tonido/tonidoconsole` what are the missing libraries, in my case this solved the dependencies:

- - - - - -

> `zypper in libopenssl0_9_8 mozilla-nss libpng12-0`

- - - - - -

We need a startup script. I created a quick (read lazy) copy of /etc/init.d/skeleton. This is the result with the original comments stripped out, to be able to copy it here, feel free to create a nice tidy replacement for it and share it!! (first possible change, run the service as a non root user if that’s a requirement for you)

- - - - - -

> `#!/bin/sh<br></br>######<br></br># Quick-Lazy startup script for Tonido<br></br># Ciro Iriarte<br></br># 2011-03-20 - v0.01<br></br>######<br></br>### BEGIN INIT INFO<br></br># Provides:          tonido<br></br># Required-Start:    $network $syslog $remote_fs<br></br># Should-Start:      $named $syslog $time<br></br># Required-Stop:     $network $syslog<br></br># Should-Stop:       $named $syslog $time<br></br># Default-Start:     3 5<br></br># Default-Stop:      0 1 2 6<br></br># Short-Description: Tonido Server<br></br># Description:       Start Tonido to provide personal cloud<br></br>### END INIT INFO`
> 
> `TONIDO_SH=/opt/tonido/tonido.sh<br></br>TONIDO_BIN=/opt/tonido/tonidoconsole<br></br>test -x $TONIDO_SH || { echo "$TONIDO_SH not installed";<br></br>if [ "$1" = "stop" ]; then exit 0;<br></br>else exit 5; fi; }`
> 
> `. /etc/rc.status`
> 
> `rc_reset`
> 
> `case "$1" in<br></br>start)<br></br>$TONIDO_SH start<br></br>rc_status -v<br></br>;;<br></br>stop)<br></br>$TONIDO_SH stop<br></br>rc_status -v<br></br>;;<br></br>restart)<br></br>$TONIDO_SH restart<br></br>rc_status<br></br>;;<br></br>status)<br></br>echo -n "Checking for service Tonido "<br></br>/sbin/checkproc $TONIDO_BIN<br></br>rc_status -v<br></br>;;`
> 
> ` *)<br></br>echo "Usage: $0 {start|stop|status|restart}"<br></br>exit 1<br></br>;;<br></br>esac<br></br>rc_exit`

- - - - - -

It should be created as /etc/init.d/tonido, don’t forget the management link and enable the service for automatic startup.

- - - - - -

> ` ln -s /etc/init.d/tonido /usr/sbin/rctonido<br></br>chkconfig tonido on<br></br>`

- - - - - -

Start the service

- - - - - -

> `rctonido start`

- - - - - -

To be able to run the service remotely, we should change the file ~/tonido/data/configex.xml and enable remote administration. Set value=1 for RemoteAdmin parameter (sorry, can’t post XML here apparently)

Restart the service to reread the configuration

- - - - - -

> `rctonido restart`

- - - - - -

If everything went fine, you should be able to access Tonido at http://server.domain.com:10001.

**Firewall configuration**

If you have a public server, it MUST have a firewall. This are the steps to configure SuSEfirewall2.  
1- Create the file /etc/sysconfig/SuSEfirewall2.d/services/tonido (rule file) and put in it the following:

- - - - - -

> `## Name: Tonido<br></br>## Description: Opens ports for Tonido server`
> 
> `# space separated list of allowed TCP ports<br></br>TCP="10001"`
> 
> `# space separated list of allowed UDP ports<br></br>UDP=""`
> 
> `# space separated list of allowed RPC services<br></br>RPC=""`
> 
> \# space separated list of allowed IP protocols  
> IP=""
> 
> `# space separated list of allowed UDP broadcast ports<br></br>BROADCAST=""<br></br>`

- - - - - -

2- Edit /etc/sysconfig/SuSEfirewall2, and add “tonido” to the FW\_CONFIGURATIONS\_EXT parameter, like this:

- - - - - -

> `W_CONFIGURATIONS_EXT="apache2 apache2-ssl bind gts mysql sshd tomcat rsync-server tonido"`

- - - - - -

3- Restart the firewall

- - - - - -

> `rcSuSEfirewall2 restart`

- - - - - -

Have fun!!