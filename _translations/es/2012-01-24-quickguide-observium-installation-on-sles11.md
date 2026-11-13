---
title: "Guía rápida: instalación de Observium en SLES11"
description: "Guía rápida de instalación de Observium, monitoreo de red, en SLES11: Apache/MySQL/PHP/rrdtool, base de datos, vhost, tareas cron y ajuste de XCache."
date: 2012-01-24 15:57:34 -0300
permalink: /es/index.php/2012/01/24/quickguide-observium-installation-on-sles11/
lang: es
categories:
  - monitoring
tags:
  - observium
  - sles
---

Me topé con una gran herramienta para recolectar datos llamada [Observium](http://www.observium.org), funciona con mysql+php+rrdtool recolectando datos vía SNMP. Aquí van mis notas basadas en la guía original para Debian+SVN.

<!--more-->

**Repositorios iniciales**

SLES11 + SLE11-SDK + Updates

**Pre-requisitos**

*# Repositorios adicionales*

> zypper ar -f http://download.opensuse.org/repositories/network:/utilities/SLE_11_SP1 network:utilities

*# Instalación de paquetes*

> zypper in apache2-mod_php5 php5-mysql php5-gd php5-snmp php5-pear net-snmp graphviz-gd graphviz subversion mysql rrdtool fping ImageMagick whois mtr nmap ipmitool

*# Módulos adicionales usando PEAR*

> pear install Net_IPv6
> pear install Net_IPv4

*# Para monitorear VMs usando libvirt*

> zypper in libvirt

*# Checkout de Observium desde SVN*

> cd /opt
> svn co http://www.observium.org/svn/observer/trunk observium

**Base de datos**

*# Creación de la BD y el usuario*

> mysql> create database observium;

> mysql> grant all privileges on observium.* to 'observium'@'localhost' -> identified by '<pass>';

*# Creación del esquema*

> cd observium

> mysql -u observium -p observium < database-schema.sql

*# Actualizar config.php para incluir la información de conexión a la BD*

> cp config.php{.default,}

> vi config.php

*# Actualizaciones del esquema*

> for F in database-update*;do scripts/update-sql.php $F;done

*# Creación de los directorios de RRD y gráficos*

> mkdir graphs rrd
> chown wwwrun: graphs/ rrd/

**RUTAS**

*# fping*

> vi config.php

> ---

> $config['fping'] = "/usr/sbin/fping";

> ---

**Apache**

*# Habilitar Mod Rewrite*

> a2enmod rewrite

*# Configuración del vhost de apache*

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

*# Directorio de destino de los logs*

> mkdir /opt/observium/logs/

> chown wwwrun: /opt/observium/logs/

*# Arranque*

> rcapache2 start
> chkconfig apache2 on

*# Usuarios (para producción, mejor configurar LDAP)*

*# Administradores, nivel 10*

> /opt/observium/adduser.php user1 pass 10

**Dispositivos**

*# Agregar nuevos dispositivos*

> cd /opt/observium/ && ./addhost.php <hostname> <community> v2c

*# Descubrimiento inicial + recolección de datos*

> ./discovery.php -h all

> ./poller.php -h all

*# Habilitar la recolección de datos usando cron*

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

**Ajuste de rendimiento**

*# Instalar XCache, reconstruir el paquete desde OBS ya que no existe para SP1*

> mkdir ~/tmp
> cd ~/tmp
> wget http://download.opensuse.org/repositories/server:/php:/extensions/SLE_11/src/php5-xcache-1.3.2-2.1.src.rpm
> rpmbuild --rebuild php5-xcache-1.3.2-2.1.src.rpm

*# Instalar el resultado del comando anterior*

*# Reiniciar apache*

> rcapache2 restart

Eso es todo, el mismo procedimiento debería funcionar con openSUSE, siempre que uses los repositorios correctos…
