---
title: "Quickguide: Observium installation on SLES11"
description: "Quick installation guide for Observium network monitoring on SLES11, covering Apache/MySQL/PHP/rrdtool setup, database configuration, vhost, cron jobs, and XCache tuning."
date: 2012-01-24 15:57:34 -0300
author: Ciro Iriarte
permalink: /index.php/2012/01/24/quickguide-observium-installation-on-sles11/
lang: en
categories:
  - monitoring
tags:
  - observium
  - sles
---

I came accross a great tool for collecting data called [Observium](http://www.observium.org), it works with mysql+php+rrdtool collecting data through SNMP. Here are my notes based on original Debian+SVN guide.

<!--more-->

**Initial Repos**

SLES11 + SLE11-SDK + Updates

**Pre-requisites**

*# Additional repositories*

{% highlight shell %}
zypper ar -f http://download.opensuse.org/repositories/network:/utilities/SLE_11_SP1 network:utilities
{% endhighlight %}

*# Prepackaged installation*

{% highlight shell %}
zypper in apache2-mod_php5 php5-mysql php5-gd php5-snmp php5-pear net-snmp graphviz-gd graphviz subversion mysql rrdtool fping ImageMagick whois mtr nmap ipmitool
{% endhighlight %}

*# Additional modules using PEAR*

{% highlight shell %}
pear install Net_IPv6
pear install Net_IPv4
{% endhighlight %}

*# For monitoring VMs using libvirt*

{% highlight shell %}
zypper in libvirt
{% endhighlight %}

*# Checkout of Observium from SVN*

{% highlight shell %}
cd /opt
svn co http://www.observium.org/svn/observer/trunk observium
{% endhighlight %}

**Data Base**

*# DB+user Creation*

{% highlight text %}
mysql> create database observium;
mysql> grant all privileges on observium.* to 'observium'@'localhost'
    -> identified by '<pass>';
{% endhighlight %}

*# Schema creation*

{% highlight shell %}
cd observium
mysql -u observium -p observium < database-schema.sql
{% endhighlight %}

*# Update config.php to include DB connection info*

{% highlight shell %}
cp config.php{.default,}
vi config.php
{% endhighlight %}

*# Schema updates*

{% highlight shell %}
for F in database-update*;do scripts/update-sql.php $F;done
{% endhighlight %}

*# RRD and graphs directory creation*

{% highlight shell %}
mkdir graphs rrd
chown wwwrun: graphs/ rrd/
{% endhighlight %}

**PATHS**

*# fping*

{% highlight shell %}
vi config.php
{% endhighlight %}

{% highlight php %}
$config['fping'] = "/usr/sbin/fping";
{% endhighlight %}

**Apache**

*# Enable Mod Rewrite*

{% highlight shell %}
a2enmod rewrite
{% endhighlight %}

*# apache vhost configuration*

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


*# Log destination directory*

{% highlight shell %}
mkdir /opt/observium/logs/
chown wwwrun: /opt/observium/logs/
{% endhighlight %}

*# Startup*

{% highlight shell %}
rcapache2 start
chkconfig apache2 on
{% endhighlight %}

*# Users (for production, better configure LDAP)*

*# Admins, level 10*

{% highlight shell %}
/opt/observium/adduser.php user1 pass 10
{% endhighlight %}

**Devices**

*# Adding new devices*

{% highlight shell %}
cd /opt/observium/ && ./addhost.php <hostname> <community> v2c
{% endhighlight %}

*# Discovery inicial + colecta de datos*

{% highlight shell %}
./discovery.php -h all
./poller.php -h all
{% endhighlight %}

*# Enable data collection using cron*

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


**Performance Tunning**

*# Install XCache, rebuild package from OBS as it's not for SP1*

{% highlight shell %}
mkdir ~/tmp
cd ~/tmp
wget http://download.opensuse.org/repositories/server:/php:/extensions/SLE_11/src/php5-xcache-1.3.2-2.1.src.rpm
rpmbuild --rebuild php5-xcache-1.3.2-2.1.src.rpm
{% endhighlight %}

*# Install result from above command*

*# Restart apache*

{% highlight shell %}
rcapache2 restart
{% endhighlight %}

That’s all, the same procedure should work with openSUSE, given you use the right repositories…
