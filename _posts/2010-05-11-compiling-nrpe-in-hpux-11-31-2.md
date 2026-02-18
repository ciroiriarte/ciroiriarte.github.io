---
id: 90
title: 'Compiling nrpe in HPUX 11.31'
date: '2010-05-11T16:20:32-04:00'
author: Ciro Iriarte
layout: post
guid: 'http://cyruspy.wordpress.com/?p=90'
permalink: /index.php/2010/05/11/compiling-nrpe-in-hpux-11-31-2/
description: 'Guide for compiling NRPE with --enable-command-args on HP-UX 11.31, including TCP wrappers workaround, nrpe.c patch, build steps, and a custom init script.'
categories:
    - Nagios
tags:
    - nagios
    - monitoring
    - hpux
    - nrpe
---

Ok, we got our brand new HP rx8640 servers running HPUX 11.31 and needed to monitor them with nagios. As check_by_ssh turned to be a lot slower than NRPE+SSL on our former Solaris servers, we defined as policy that every server under our control should be monitored using NRPE.

Found that [someone ](http://www.mayoxide.com/naghpux/)already did the nasty work of compiling it and even created a current depot (software package in HPUX terms) that works with 11.31. There are a couple of drawbacks though, it runs using inetd which is not practical when you run a lot of frequent checks and it's compiled without the "--enable-command-args" and this last bit makes it useless for our needs.

Using Olivier's build notes, slightly modified, I've built NRPE with "--enable-command-args" and created a script to start it as a standalone service rather than using inetd.

<!-- more -->

Here's the process:

## **TCP Wrappers note**

According to Olivier’s notes, he used the tcpwrapper’s source included with SSHD (is it Openssh?) located at /opt/ssh/src/tcp\_wrappers\_7.6-ipv6.4. To be able to build it, I had to modify the Makefile, adding “-DUSE\_GETDOMAIN” to the BUGS macro definition. Otherwise, I was getting the following error:

{% highlight shell %}
/usr/ccs/bin/ld: Unsatisfied symbols: yp_get_default_domain (code)
{% endhighlight %}

Procedure:

{% highlight shell %}
vi Makefile <-- add "-DUSE_GETDOMAIN" to BUGS macro definition
make REAL_DAEMON_DIR=/tmp hpux
ls -l libwrap.a
{% endhighlight %}

The thing is, it didn’t work…. After building it and using the generated libwrap.a at NRPE compilation time, I was getting:

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

Going back with stock libwrap on HPUX, I only needed to define a missing variable for it in nrpe.c (rfc931\_timeout)

## **Patching/modifying NRPE**

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

## **NRPE configuration**

{% highlight shell %}
PATH="$(cat /etc/PATH):/usr/local/bin" ./configure --prefix=/opt/nagios \
   --with-ssl-inc=/opt/openssl/include --with-ssl-lib=/opt/openssl/lib/hpux32 \
   --enable-command-args
{% endhighlight %}

## **Compilation & Installation**

{% highlight shell %}
make
make install
mkdir /opt/nagios/etc
cp sample-config/nrpe.cfg /opt/nagios/etc/
{% endhighlight %}

## **Init script**

I created a init script to start NRPE as a service, but apparently wordpress doesn’t allow any arbitrary file to be uploaded. I’ll upload it as soon as possible.

Update: As I’m unable to post files, I’ll have to include the script inline…. For this to work you need two files, one for “enablement” of the service and the control script.

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

After creating those files you’ll need to make links to the control script to be able to start and stop on boot and shutdown

{% highlight shell %}
/sbin/rc1.d/K500nrpe -/sbin/init.d/nrpe
/sbin/rc3.d/S999nrpe -/sbin/init.d/nrpe
{% endhighlight %}

Those were the missing bits…