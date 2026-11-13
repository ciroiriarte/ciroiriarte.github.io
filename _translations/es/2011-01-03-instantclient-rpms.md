---
title: InstantClient RPMs
description: "Comparto un archivo spec RPM mejorado de Oracle InstantClient basado en el trabajo de Remi Collet, con ORACLE_HOME, soporte para tnsnames.ora y otras mejoras, para openSUSE Build Service."
date: 2011-01-03 00:59:38 -0300
permalink: /es/index.php/2011/01/03/instantclient-rpms/
lang: es
categories:
  - linux
tags:
  - oracle
  - rpm
  - opensuse
---

Bueno, hace unos años me encontré con el archivo SPEC de Oracle InstantClient preparado por Remi Collet, y fue genial encontrarlo porque los RPM originales hechos por Oracle no sirven para compilar otros paquetes que dependen de ellos.

<!--more-->

Creé un conjunto de paquetes para un proyecto usando el archivo original de Remi. Unos días después los mejoré para que el uso del paquete por parte de los usuarios finales fuera realmente fluido (variable de entorno ORACLE\_HOME, PATHs, etc). También agregué otros ajustes, como un script para ayudar a compilar Perl-DBD-Oracle (que no hice yo), y quedé muy contento con los resultados. Aquí es donde todo se vino abajo. En el openSUSE Build Service había una política de permitir solo software con código fuente y los encargados simplemente borraron el paquete de mi proyecto de repositorio y perdí todo el trabajo hecho.

Tenía la recreación del paquete en mi lista de pendientes, pero nunca tuve tiempo de hacerlo… Unos días antes, frente a un nuevo proyecto con Oracle, fui al blog de Remi a buscar el archivo SPEC original y por suerte, un mes antes más o menos, [lo había modificado](http://blog.famillecollet.com/post/2010/11/12/RPM-Oracle-Instant-Client-11.2-en) para soportar la última versión del cliente (a esta fecha, 10.2.0.2).

Le hice algunos cambios (a ellos, ya que estaban divididos en dos) y comparto aquí el resultado. Como toque final voy a agregar tnsping a los paquetes, que solo se incluye en la instalación “thick” de Oracle y quizás una el sub-paquete “precomp\*” con “devel”.

**Archivos:**

[oracle-instantclient.spec](http://track.itsolutions.com.py/pub/oracle/oracle-instantclient.spec)  
[oracle-instantclient-11.2.0.2.0-37.1.nosrc.rpm](http://track.itsolutions.com.py/pub/oracle/oracle-instantclient.spec)

**Mis cambios a los archivos SPEC de Remi:**

{% highlight text %}
* Sun Jan 2 2011 Ciro Iriarte  11.2.0.2.0
- Added ORACLE_HOME definition
- Added tnsnames.ora example and required directory structure

* Sat Jan 1 2011 Ciro Iriarte 11.2.0.2.0
- merge i386/x86_64 SPECs again
- fixed RPM Groups
- added Jean-Christophe Duberga's config script to help building Perl-DBD-Oracle
 (this wasn't documented on my first change in 2007, and was lost in OBS)
- skip RPATH and BYTECODE verifications in OBS builds
- renamed oracle-instantclient-basic to oracle-instantclient
- added unzip to BuildRequires
- general cleanup to make openSUSE 11.3 sanity checks happy
 o ToDo: Verify rpmlint filters
- add precomp and precomp-devel sub-packages
{% endhighlight %}

**Ref:**

 [Solicitud para permitir OIC en Build Service](https://features.opensuse.org/308967)
