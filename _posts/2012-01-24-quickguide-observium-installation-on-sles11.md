---
id: 158
title: 'Quickguide: Observium installation on SLES11'
date: '2012-01-24T15:57:34-03:00'
author: Ciro Iriarte
layout: post
guid: 'http://cyruspy.wordpress.com/?p=158'
permalink: /index.php/2012/01/24/quickguide-observium-installation-on-sles11/
description: 'Quick installation guide for Observium network monitoring on SLES11, covering Apache/MySQL/PHP/rrdtool setup, database configuration, vhost, cron jobs, and XCache tuning.'
categories:
    - Linux
    - OSS
tags:
    - monitoring
    - observium
    - sles
    - networking
---

I came accross a great tool for collecting data called [Observium](http://www.observium.org), it works with mysql+php+rrdtool collecting data through SNMP. Here are my notes based on original Debian+SVN guide.

<!-- more -->

**Initial Repos**

SLES11 + SLE11-SDK + Updates

**Pre-requisites**

*# Additional repositories*

> zypper ar -f http://download.opensuse.org/repositories/network:/utilities/SLE_11_SP1 network:utilities

*# Prepackaged installation*

> zypper in apache2-mod_php5 php5-mysql php5-gd php5-snmp php5-pear net-snmp graphviz-gd graphviz subversion mysql rrdtool fping ImageMagick whois mtr nmap ipmitool

*# Additional modules using PEAR*

> pear install Net_IPv6
> pear install Net_IPv4

*# For monitoring VMs using libvirt*

> zypper in libvirt

*# Checkout of Observium from SVN*

> cd /opt
> svn co http://www.observium.org/svn/observer/trunk observium

**Data Base**

*# DB+user Creation*

> mysql> create database observium;

> mysql> grant all privileges on observium.* to 'observium'@'localhost' -> identified by '<pass>';

*# Schema creation*

> cd observium

> mysql -u observium -p observium < database-schema.sql

*# Update config.php to include DB connection info*

> cp config.php{.default,}

> vi config.php

*# Schema updates*

> for F in database-update*;do scripts/update-sql.php $F;done

*# RRD and graphs directory creation*

> mkdir graphs rrd
> chown wwwrun: graphs/ rrd/

**PATHS**

*# fping*

> vi config.php

> ---

> $config['fping'] = "/usr/sbin/fping";

> ---

**Apache**

*# Enable Mod Rewrite*

> a2enmod rewrite

*# apache vhost configuration*

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

*# Log destination directory*

> mkdir /opt/observium/logs/

> chown wwwrun: /opt/observium/logs/

*# Startup*

> rcapache2 start
> chkconfig apache2 on

*# Users (for production, better configure LDAP)*

*# Admins, level 10*

> /opt/observium/adduser.php user1 pass 10

**Devices**

*# Adding new devices*

> cd /opt/observium/ && ./addhost.php <hostname> <community> v2c

*# Discovery inicial + colecta de datos*

> ./discovery.php -h all

> ./poller.php -h all

*# Enable data collection using cron*

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

**Performance Tunning**

*# Install XCache, rebuild package from OBS as it's not for SP1*

> mkdir ~/tmp
> cd ~/tmp
> wget http://download.opensuse.org/repositories/server:/php:/extensions/SLE_11/src/php5-xcache-1.3.2-2.1.src.rpm
> rpmbuild --rebuild php5-xcache-1.3.2-2.1.src.rpm

*# Install result from above command*

*# Restart apache*

> rcapache2 restart

That’s all, the same procedure should work with openSUSE, given you use the right repositories…