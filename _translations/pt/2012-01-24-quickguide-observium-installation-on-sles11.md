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

{% highlight shell %}
zypper ar -f http://download.opensuse.org/repositories/network:/utilities/SLE_11_SP1 network:utilities
{% endhighlight %}

*# Instalação dos pacotes*

{% highlight shell %}
zypper in apache2-mod_php5 php5-mysql php5-gd php5-snmp php5-pear net-snmp graphviz-gd graphviz subversion mysql rrdtool fping ImageMagick whois mtr nmap ipmitool
{% endhighlight %}

*# Módulos adicionais usando PEAR*

{% highlight shell %}
pear install Net_IPv6
pear install Net_IPv4
{% endhighlight %}

*# Para monitorar VMs usando libvirt*

{% highlight shell %}
zypper in libvirt
{% endhighlight %}

*# Checkout do Observium a partir do SVN*

{% highlight shell %}
cd /opt
svn co http://www.observium.org/svn/observer/trunk observium
{% endhighlight %}

**Banco de dados**

*# Criação do BD e do usuário*

{% highlight text %}
mysql> create database observium;
mysql> grant all privileges on observium.* to 'observium'@'localhost'
    -> identified by '<pass>';
{% endhighlight %}

*# Criação do esquema*

{% highlight shell %}
cd observium
mysql -u observium -p observium < database-schema.sql
{% endhighlight %}

*# Atualizar o config.php para incluir as informações de conexão ao BD*

{% highlight shell %}
cp config.php{.default,}
vi config.php
{% endhighlight %}

*# Atualizações do esquema*

{% highlight shell %}
for F in database-update*;do scripts/update-sql.php $F;done
{% endhighlight %}

*# Criação dos diretórios de RRD e gráficos*

{% highlight shell %}
mkdir graphs rrd
chown wwwrun: graphs/ rrd/
{% endhighlight %}

**CAMINHOS**

*# fping*

{% highlight shell %}
vi config.php
{% endhighlight %}

{% highlight php %}
$config['fping'] = "/usr/sbin/fping";
{% endhighlight %}

**Apache**

*# Habilitar o Mod Rewrite*

{% highlight shell %}
a2enmod rewrite
{% endhighlight %}

*# Configuração do vhost do apache*

{% highlight shell %}
vi /etc/apache2/vhosts.d/observium.conf
{% endhighlight %}

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


*# Diretório de destino dos logs*

{% highlight shell %}
mkdir /opt/observium/logs/
chown wwwrun: /opt/observium/logs/
{% endhighlight %}

*# Inicialização*

{% highlight shell %}
rcapache2 start
chkconfig apache2 on
{% endhighlight %}

*# Usuários (para produção, é melhor configurar LDAP)*

*# Administradores, nível 10*

{% highlight shell %}
/opt/observium/adduser.php user1 pass 10
{% endhighlight %}

**Dispositivos**

*# Adicionando novos dispositivos*

{% highlight shell %}
cd /opt/observium/ && ./addhost.php <hostname> <community> v2c
{% endhighlight %}

*# Descoberta inicial + coleta de dados*

{% highlight shell %}
./discovery.php -h all
./poller.php -h all
{% endhighlight %}

*# Habilitar a coleta de dados usando o cron*

{% highlight shell %}
vi /etc/cron.d/observium
{% endhighlight %}

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


**Ajuste de desempenho**

*# Instalar o XCache, reconstruir o pacote a partir do OBS, já que não existe para o SP1*

{% highlight shell %}
mkdir ~/tmp
cd ~/tmp
wget http://download.opensuse.org/repositories/server:/php:/extensions/SLE_11/src/php5-xcache-1.3.2-2.1.src.rpm
rpmbuild --rebuild php5-xcache-1.3.2-2.1.src.rpm
{% endhighlight %}

*# Instalar o resultado do comando acima*

*# Reiniciar o apache*

{% highlight shell %}
rcapache2 restart
{% endhighlight %}

É isso, o mesmo procedimento deve funcionar com openSUSE, desde que você use os repositórios certos…
