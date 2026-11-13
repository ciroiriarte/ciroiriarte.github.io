---
title: Instalação rápida do Tonido no openSUSE
description: "Passo a passo para instalar a plataforma de nuvem pessoal Tonido no openSUSE usando o alien para converter pacotes deb, com script de inicialização e configuração do SuSEfirewall2."
date: 2011-03-20 02:08:33 -0300
permalink: /pt/index.php/2011/03/20/quick-tonido-installation-on-opensuse/
lang: pt
categories:
  - linux
tags:
  - opensuse
  - tonido
---

Bom, na semana passada atualizei meu laptop para o openSUSE 11.4 e isso, infelizmente, quebrou minha instalação do MoneyManagerEx, porque eu precisava de um pacote para essa nova distro e o do Packman está quebrado por causa de algumas [mudanças](http://www.mail-archive.com/packman@links2linux.de/msg05268.html) no repo.

Como tenho uma pilha de despesas pendentes para lançar na minha contabilidade, eu precisava urgentemente de uma instalação do MMEx funcionando, então fui até a [homepage](http://www.codelathe.com/mmex/) procurar a versão mais recente e consertar meu [pacote](https://build.opensuse.org/package/show?package=moneymanagerex&project=home%3Aciriarte) no OBS, que está quebrado há meses por causa da minha preguiça ¬¬’

Foi aí que eu vi: existe uma versão web do MMEx!!!, e isso é ótimo porque me permitiria usá-lo do meu novo celular Android sem precisar acessar o laptop, “talvez seja totalmente funcional no navegador” pensei….. Lendo um pouco mais, descobri que ele fazia parte de uma plataforma de nuvem chamada Tonido. Parecia muita dor de cabeça só para rodar a aplicação, mas quando descobri que o Tonido tem um aplicativo Android dedicado, estava vendido!.

[Aqui](http://www.tonido.com/tonidocloud_what.html) estão as opções do Tonido, que vão de um appliance super legal a um serviço em nuvem, passando pela sua própria instalação local. Como já tenho um VPS, usar o Tonido nele parece uma boa solução: não preciso depender da conexão porcaria do meu ISP nem do uptime do meu desktop (a companhia elétrica local não é garantia de nada).

O VPS roda openSUSE 11.3 @i586 (ou seja, a versão de 32 bits). O Tonido não fornece código-fonte nem tarballs genéricos, então vamos trabalhar com pacotes deb para Ubuntu. Como tarefa pendente, talvez eu monte um pacote limpinho no [OBS](https://build.opensuse.org) para automatizar o procedimento que vou documentar aqui; por enquanto esta é uma "documentação de um hack rápido, sujo se você preferir". Além disso, note que esta é uma instalação em servidor dedicado, não contempla "integração com o desktop", que fica de fora.

<!--more-->

Primeiro, precisamos instalar o alien, para converter o pacote deb em rpm, de onde extrairemos os arquivos.

{% highlight shell %}
zypper in http://download.opensuse.org/repositories/openSUSE:/11.3:/Contrib/standard/i586/alien-8.80-1.2.i586.rpm
{% endhighlight %}

Este pacote vem do repositório Contrib, o zypper cuidará das dependências para nós. Agora, devemos baixar o pacote deb original.

{% highlight shell %}
vps:~ # mkdir tmp
vps:~/tmp # wget http://www.tonidoid.com/download.php?TonidoSetup_i686.deb
vps:~/tmp # mv download.php?TonidoSetup_i686.deb TonidoSetup_i686.deb
{% endhighlight %}

Faremos esta conversão para extrair os arquivos: deb -> rpm -> cpio

{% highlight shell %}
vps:~/tmp # alien -r TonidoSetup_i686.deb
vps:~/tmp # mkdir extracted
vps:~/tmp # cd extracted
vps:~/tmp/extracted # rpm2cpio ../tonido-2.26.0.13504-2.i386.rpm |cpio -idmv
{% endhighlight %}

O procedimento extrairá todos os arquivos para ~/tmp/extracted; vamos realocar os arquivos para um lugar apropriado e limpar as sobras…

{% highlight shell %}
vps:~/tmp/extracted # mv usr/local/tonido /opt
vps:~/tmp/extracted # cd
vps:~ # rm -rf tmp
{% endhighlight %}

O script de inicialização incluído é /opt/tonido/tonido.sh; fiz algumas mudanças na localização de alguns arquivos para deixar as coisas mais “padrão”. Aqui está um diff com as mudanças (pergunte ao google como aplicar um patch)

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

Próximo passo, corrigir as dependências. Se você estiver instalando o Tonido em outra distro, deve verificar com `ldd /etc/tonido/tonidoconsole` quais são as bibliotecas que faltam; no meu caso isto resolveu as dependências:

{% highlight shell %}
zypper in libopenssl0_9_8 mozilla-nss libpng12-0
{% endhighlight %}

Precisamos de um script de inicialização. Fiz uma cópia rápida (leia-se preguiçosa) de /etc/init.d/skeleton. Este é o resultado com os comentários originais removidos, para poder copiá-lo aqui; fique à vontade para criar um substituto bem arrumado e compartilhá-lo!! (primeira mudança possível: rodar o serviço com um usuário não root, se for um requisito para você)

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

Ele deve ser criado como /etc/init.d/tonido; não esqueça o link de gerenciamento e de habilitar o serviço para inicialização automática.

{% highlight shell %}
ln -s /etc/init.d/tonido /usr/sbin/rctonido
chkconfig tonido on
{% endhighlight %}

Inicie o serviço

{% highlight shell %}
rctonido start
{% endhighlight %}

Para poder administrar o serviço remotamente, devemos alterar o arquivo ~/tonido/data/configex.xml e habilitar a administração remota. Defina value=1 no parâmetro RemoteAdmin (desculpe, pelo visto não dá para postar XML aqui)

Reinicie o serviço para que ele releia a configuração

{% highlight shell %}
rctonido restart
{% endhighlight %}

Se tudo deu certo, você deve conseguir acessar o Tonido em http://server.domain.com:10001.

## Configuração do firewall {#firewall-configuration}

Se você tem um servidor público, ele DEVE ter um firewall. Estes são os passos para configurar o SuSEfirewall2.

1. Crie o arquivo /etc/sysconfig/SuSEfirewall2.d/services/tonido (arquivo de regras) e coloque nele o seguinte:

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

2. Edite /etc/sysconfig/SuSEfirewall2 e adicione “tonido” ao parâmetro `FW_CONFIGURATIONS_EXT`, assim:

{% highlight shell %}
FW_CONFIGURATIONS_EXT="apache2 apache2-ssl bind gts mysql sshd tomcat rsync-server tonido"
{% endhighlight %}

3. Reinicie o firewall

{% highlight shell %}
rcSuSEfirewall2 restart
{% endhighlight %}

Divirta-se!!
