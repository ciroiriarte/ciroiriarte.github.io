---
title: Modificare i fusi orari
description: "Guida alla modifica dei file dei fusi orari su Linux usando zic e il database Olson, con un esempio per il Paraguay."
date: 2006-03-29 01:50:01 -0400
permalink: /it/index.php/2006/03/29/modificando-zonas-horarias/
lang: it
categories:
  - linux
tags:
  - timezone
---

## Intro {#intro}

I file con le informazioni sui fusi orari e sul popolare “daylight saving” si trovano in /usr/share/zoneinfo. Possono essere consultati con:

{% highlight shell %}
zdump -v "archivo"
{% endhighlight %}

Nel nostro caso è molto comune che cambino le date in cui avviene il cambio dell'ora; per correggere questo, bisogna ricompilare questi file dopo averli modificati, e lo si fa con il comando zic.

<!--more-->

Le definizioni dei fusi si scaricano da [ftp://elsie.nci.nih.gov/pub/](ftp://elsie.nci.nih.gov/pub/)

## Procedura (esempio per il Paraguay) {#procedimiento-ejemplo-para-paraguay}

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
