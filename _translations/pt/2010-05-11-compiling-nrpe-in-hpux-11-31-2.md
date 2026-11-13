---
title: "Compilando o nrpe no HPUX 11.31"
description: "Guia para compilar o NRPE com --enable-command-args no HP-UX 11.31, incluindo o workaround dos TCP wrappers, o patch do nrpe.c, os passos de compilação e um script de init próprio."
date: 2010-05-11 16:20:32 -0400
permalink: /pt/index.php/2010/05/11/compiling-nrpe-in-hpux-11-31-2/
lang: pt
categories:
  - monitoring
tags:
  - nagios
  - hpux
---

Ok, chegaram nossos novos servidores HP rx8640 com HPUX 11.31 e precisávamos monitorá-los com o nagios. Como o check_by_ssh se mostrou muito mais lento que o NRPE+SSL nos nossos antigos servidores Solaris, definimos como política que todo servidor sob nosso controle deve ser monitorado usando NRPE.

Descobri que [alguém ](http://www.mayoxide.com/naghpux/)já fez o trabalho sujo de compilá-lo e até criou um depot atual (pacote de software, na linguagem do HPUX) que funciona com o 11.31. Tem algumas desvantagens, porém: roda via inetd, o que não é prático quando você faz muitas verificações frequentes, e foi compilado sem "--enable-command-args", e esse último ponto o torna inútil para o que precisamos.

Usando as notas de build do Olivier, levemente modificadas, compilei o NRPE com "--enable-command-args" e criei um script para iniciá-lo como serviço standalone em vez de usar o inetd.

<!--more-->

Aqui está o processo:

## **Nota sobre TCP Wrappers** {#tcp-wrappers-note}

Segundo as notas do Olivier, ele usou o código-fonte do tcpwrapper incluído com o SSHD (será o Openssh?) localizado em /opt/ssh/src/tcp\_wrappers\_7.6-ipv6.4. Para conseguir compilá-lo, tive que modificar o Makefile, adicionando “-DUSE\_GETDOMAIN” à definição da macro BUGS. Caso contrário, eu recebia o seguinte erro:

{% highlight shell %}
/usr/ccs/bin/ld: Unsatisfied symbols: yp_get_default_domain (code)
{% endhighlight %}

Procedimento:

{% highlight shell %}
vi Makefile <-- add "-DUSE_GETDOMAIN" to BUGS macro definition
make REAL_DAEMON_DIR=/tmp hpux
ls -l libwrap.a
{% endhighlight %}

O problema é que não funcionou…. Depois de compilá-lo e usar o libwrap.a gerado na compilação do NRPE, eu recebia:

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

Voltando ao libwrap padrão do HPUX, só precisei definir no nrpe.c uma variável que estava faltando (rfc931\_timeout)

## **Aplicando patch/modificando o NRPE** {#patchingmodifying-nrpe}

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

## **Configuração do NRPE** {#nrpe-configuration}

{% highlight shell %}
PATH="$(cat /etc/PATH):/usr/local/bin" ./configure --prefix=/opt/nagios \
   --with-ssl-inc=/opt/openssl/include --with-ssl-lib=/opt/openssl/lib/hpux32 \
   --enable-command-args
{% endhighlight %}

## **Compilação e instalação** {#compilation--installation}

{% highlight shell %}
make
make install
mkdir /opt/nagios/etc
cp sample-config/nrpe.cfg /opt/nagios/etc/
{% endhighlight %}

## **Script de init** {#init-script}

Criei um script de init para iniciar o NRPE como serviço, mas aparentemente o wordpress não permite o upload de arquivos arbitrários. Vou publicá-lo assim que possível.

Atualização: Como não consigo publicar arquivos, vou ter que incluir o script aqui mesmo…. Para isso funcionar você precisa de dois arquivos, um para “habilitar” o serviço e o script de controle.

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

Depois de criar esses arquivos você precisará criar links para o script de controle para poder iniciar e parar o serviço na inicialização e no desligamento

{% highlight shell %}
/sbin/rc1.d/K500nrpe -/sbin/init.d/nrpe
/sbin/rc3.d/S999nrpe -/sbin/init.d/nrpe
{% endhighlight %}

Eram essas as peças que faltavam…
