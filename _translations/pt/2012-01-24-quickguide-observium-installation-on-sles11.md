---
title: "Guia rápido: instalação do Observium no SLES11"
description: "Guia rápido de instalação do Observium, monitoramento de rede, no SLES11: Apache/MySQL/PHP/rrdtool, banco de dados, vhost, jobs de cron e ajuste do XCache."
date: 2012-01-24 15:57:34 -0300
permalink: /pt/index.php/2012/01/24/quickguide-observium-installation-on-sles11/
lang: pt
categories:
  - monitoring
tags:
  - observium
  - sles
---

Esbarrei numa ótima ferramenta para coletar dados chamada [Observium](http://www.observium.org), que funciona com mysql+php+rrdtool coletando dados via SNMP. Aqui estão minhas anotações baseadas no guia original para Debian+SVN.

<!--more-->

**Repositórios iniciais**

SLES11 + SLE11-SDK + Updates

**Pré-requisitos**

*# Repositórios adicionais*

> zypper ar -f http://download.opensuse.org/repositories/network:/utilities/SLE_11_SP1 network:utilities

*# Instalação dos pacotes*

> zypper in apache2-mod_php5 php5-mysql php5-gd php5-snmp php5-pear net-snmp graphviz-gd graphviz subversion mysql rrdtool fping ImageMagick whois mtr nmap ipmitool

*# Módulos adicionais usando PEAR*

> pear install Net_IPv6
> pear install Net_IPv4

*# Para monitorar VMs usando libvirt*

> zypper in libvirt

*# Checkout do Observium a partir do SVN*

> cd /opt
> svn co http://www.observium.org/svn/observer/trunk observium

**Banco de dados**

*# Criação do BD e do usuário*

> mysql> create database observium;

> mysql> grant all privileges on observium.* to 'observium'@'localhost' -> identified by '<pass>';

*# Criação do esquema*

> cd observium

> mysql -u observium -p observium < database-schema.sql

*# Atualizar o config.php para incluir as informações de conexão ao BD*

> cp config.php{.default,}

> vi config.php

*# Atualizações do esquema*

> for F in database-update*;do scripts/update-sql.php $F;done

*# Criação dos diretórios de RRD e gráficos*

> mkdir graphs rrd
> chown wwwrun: graphs/ rrd/

**CAMINHOS**

*# fping*

> vi config.php

> ---

> $config['fping'] = "/usr/sbin/fping";

> ---

**Apache**

*# Habilitar o Mod Rewrite*

> a2enmod rewrite

*# Configuração do vhost do apache*

> vi /etc/apache2/vhosts.d/observium.conf

> ---

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

> ---

*# Diretório de destino dos logs*

> mkdir /opt/observium/logs/

> chown wwwrun: /opt/observium/logs/

*# Inicialização*

> rcapache2 start
> chkconfig apache2 on

*# Usuários (para produção, é melhor configurar LDAP)*

*# Administradores, nível 10*

> /opt/observium/adduser.php user1 pass 10

**Dispositivos**

*# Adicionando novos dispositivos*

> cd /opt/observium/ && ./addhost.php <hostname> <community> v2c

*# Descoberta inicial + coleta de dados*

> ./discovery.php -h all

> ./poller.php -h all

*# Habilitar a coleta de dados usando o cron*

> vi /etc/cron.d/observium

> ---

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

> ---

**Ajuste de desempenho**

*# Instalar o XCache, reconstruir o pacote a partir do OBS, já que não existe para o SP1*

> mkdir ~/tmp
> cd ~/tmp
> wget http://download.opensuse.org/repositories/server:/php:/extensions/SLE_11/src/php5-xcache-1.3.2-2.1.src.rpm
> rpmbuild --rebuild php5-xcache-1.3.2-2.1.src.rpm

*# Instalar o resultado do comando acima*

*# Reiniciar o apache*

> rcapache2 restart

É isso, o mesmo procedimento deve funcionar com openSUSE, desde que você use os repositórios certos…
