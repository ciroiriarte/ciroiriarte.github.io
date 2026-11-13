---
title: Modifying time zones
description: "Guide to modifying time zone files on Linux using zic and the Olson database, with an example for Paraguay."
date: 2006-03-29 01:50:01 -0400
permalink: /en/index.php/2006/03/29/modificando-zonas-horarias/
lang: en
categories:
  - linux
tags:
  - timezone
---

## Intro {#intro}

The files with information about time zones and the popular “daylight saving” are in /usr/share/zoneinfo. They can be inspected with:

{% highlight shell %}
zdump -v "archivo"
{% endhighlight %}

In our case it's very common for the dates when the clock change happens to be modified; to fix this, these files have to be recompiled after modifying them, which is done with the zic command.

<!--more-->

The zone definitions are downloaded from [ftp://elsie.nci.nih.gov/pub/](ftp://elsie.nci.nih.gov/pub/)

## Procedure (example for Paraguay) {#procedimiento-ejemplo-para-paraguay}

{% highlight shell %}

# Realizar copia de seguridad  
cp -rp /usr/share/zoneinfo{,.$(date +%Y%m%d)}

# Obtener source:  
mkdir -p /tmp/tzdata && cd /tmp/tzdata  
wget 'ftp://elsie.nci.nih.gov/pub/tzdata*.tar.gz'

# Realizar modificacion
tar xvzf tzdata*
vi southamerica

# Compilar  
/usr/sbin/zic southamerica

# Definir zona horaria  
cp /usr/share/zoneinfo/America/Asuncion /etc/localtime
{% endhighlight %}
