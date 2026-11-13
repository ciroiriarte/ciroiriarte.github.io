---
title: Modificando zonas horarias
description: "Guía para modificar archivos de zonas horarias en Linux usando zic y la base de datos Olson, con un ejemplo para Paraguay."
date: 2006-03-29 01:50:01 -0400
author: Ciro Iriarte
permalink: /index.php/2006/03/29/modificando-zonas-horarias/
lang: es
categories:
  - linux
tags:
  - timezone
---

## Intro

Los archivos con informacion sobre las zonas horarias y el popular “daylight saving” se encuentran en /usr/share/zoneinfo. Los mismos pueden ser consultados con:

{% highlight shell %}
zdump -v "archivo"
{% endhighlight %}

En nuestro caso es muy comun el que cambien las fechas donde se efectua el cambio de hora, para corregir esto hay que recompilar estos archivos luego de modificarlos, esto se realiza con el comando zic.

<!--more-->

Las definiciones de zonas se bajan de [ftp://elsie.nci.nih.gov/pub/](ftp://elsie.nci.nih.gov/pub/)

## Procedimiento (ejemplo para Paraguay)

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
