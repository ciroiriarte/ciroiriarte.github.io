---
id: 58
title: 'Cambio de hora en Paraguay 2010'
date: '2010-03-02T17:17:04-03:00'
author: Ciro Iriarte
layout: post
guid: 'http://cyruspy.wordpress.com/?p=58'
permalink: /index.php/2010/03/02/cambio-de-hora-en-paraguay-2010/
description: 'Guía sobre el cambio de reglas DST en Paraguay en 2010 y cómo actualizar la base de datos de zonas horarias Olson en Linux, Solaris, Tru64 y HP-UX.'
categories:
    - Linux
tags:
    - linux
    - timezone
    - paraguay
    - dst
---

El Gobierno Paraguayo resolvió modificar la fecha de entrada en vigencia del horario de invierno en toda la república. Con el anterior decreto vigente desde el 2004 se tenia que la hora debía retrasarse en 60 minutos el segundo domingo de Marzo (14/Mar este año) y volver a adelantarse en 60 minutos el tercer domingo de Octubre (17/Oct este año).

Con el nuevo decreto esto cambia a retrasar la hora en 60 minutos el segundo domingo de Abril (11/Abr este año) y volver a adelantarla en 60 minutos el primer domingo de Octubre (3/Oct este año).

<!-- more -->

Referencias:

http://www.abc.com.py/abc/nota/78024-En-abril-se-atrasa-la-hora/

http://www.presidencia.gov.py/v1/wp-content/uploads/2010/02/decreto3958.pdf

Bueno, esto que implica para los que trabajamos con sistemas unix?. En un equipo unix se mantiene la hora interna del sistema en UTC, y se ajusta la hora local según los usos horarios (o zona horaria). Para esto se utiliza la base de datos Olson, que registra las diferentes zonas horarias y las reglas para el cambio a horarios de verano (daylight saving transition o DST) según corresponda.

Esta base de datos puede bajarse en su ultima versión de ftp://elsie.nci.nih.gov/pub/tzdata*.tar.gz. Si no tenemos la suerte de que se refleje esta nueva legislación, debemos realizar los cambios a mano.

En nuestro caso, debemos limitar la ultima regla (que empieza en el 2004) al 2009 y agregar una nueva regla que este vigente desde el 2010 hasta “final de los tiempos”. Probablemente esta no sea la ultima regla a agregar, pero hasta que no haya una nueva, debería tener vigencia indefinida.

Asi quedaria sin los comentarios:

```
# Paraguay
Rule    Para    1975    1988    -    Oct     1    0:00    1:00    S
Rule    Para    1975    1978    -    Mar     1    0:00    0    -
Rule    Para    1979    1991    -    Apr     1    0:00    0    -
Rule    Para    1989    only    -    Oct    22    0:00    1:00    S
Rule    Para    1990    only    -    Oct     1    0:00    1:00    S
Rule    Para    1991    only    -    Oct     6    0:00    1:00    S
Rule    Para    1992    only    -    Mar     1    0:00    0    -
Rule    Para    1992    only    -    Oct     5    0:00    1:00    S
Rule    Para    1993    only    -    Mar    31    0:00    0    -
Rule    Para    1993    1995    -    Oct     1    0:00    1:00    S
Rule    Para    1994    1995    -    Feb    lastSun    0:00    0    -
Rule    Para    1996    only    -    Mar     1    0:00    0    -
Rule    Para    1996    2001    -    Oct    Sun>=1    0:00    1:00    S
Rule    Para    1997    only    -    Feb    lastSun    0:00    0    -
Rule    Para    1998    2001    -    Mar    Sun>=1    0:00    0    -
Rule    Para    2002    2004    -    Apr    Sun>=1    0:00    0    -
Rule    Para    2002    2003    -    Sep    Sun>=1    0:00    1:00    S
Rule    Para    2004    2009    -    Oct    Sun>=15    0:00    1:00    S
Rule    Para    2005    2009    -    Mar    Sun>=8    0:00    0    -
Rule    Para    2010    max    -       Oct     Sun>=1  0:00    1:00    S
Rule    Para    2010    max    -       Apr     Sun>=8  0:00    0       -

# Zone    NAME        GMTOFF    RULES    FORMAT    [UNTIL]
Zone America/Asuncion    -3:50:40 -    LMT    1890
            -3:50:40 -    AMT    1931 Oct 10 # Asuncion Mean Time
            -4:00    -    PYT    1972 Oct # Paraguay Time
            -3:00    -    PYT    1974 Apr
            -4:00    Para    PY%sT
```

Guardamos estas lineas en un archivo de texto plano para luego ser compilado: **/root/america\_asuncion.zone**

Para los siguientes unix y unix-like, detallo el procedimiento de verificación de fecha de cambio de hora y de corrección.

## Linux

- Estado inicial

**\#** zdump -v America/Asuncion |grep 2010

- Crear archivo con el contenido listado mas arriba

**\#** vi /root/america\_asuncion.zone

- Compilar la zona horaria

**\#** zic /root/america\_asuncion.zone

- Verificar cambios, la salida debería diferir de la salida original

**\#** zdump -v America/Asuncion |grep 2010

- Copiamos la zona a /etc/localtime. Antiguamente se utilizaba un link simbolico, pero a veces daba problemas de “archivo no encontrado” cuando /usr era un sistema de archivos separado.

**\#** cp /usr/share/zoneinfo/America/Asuncion /etc/localtime

## Solaris

- Estado inicial

**\#** zdump -v America/Asuncion|grep 2010

- Crear america\_asuncion.zone

**\#** vi /root/america\_asuncion.zone

- Compilar reglas

**\#** zic /root/america\_asuncion.zone

- Verificar cambios

**\#** zdump -v America/Asuncion|grep 2010

- Asegurarse que el sistema utilice la zona correcta:

**\#** grep TZ= /etc/TIMEZONE  
TZ=America/Asuncion

## Tru64

- Verificar estado inicial

**\#** zdump -v America/Asuncion|grep 2010

- Crear el archivo con las reglas

**\#** vi /root/america\_asuncion.zone

- Compilar archivo de reglas

**\#** zic /root/america\_asuncion.zone

- Verificar cambios

**\#** zdump -v America/Asuncion|grep 2010

## HPUX

Bueno, no utiliza la base de datos Olson, y mantiene sus propias reglas para DST.

- Corroborar el estado actual, para este paso necesitamos el script dst.pl, puede ser bajado de los foros de HP

Ref:

http://forums11.itrc.hp.com/service/forums/questionanswer.do?threadId=1089676  
http://forums11.itrc.hp.com/service/forums/questionanswer.do?admit=109447626+1267560461229+28353475&threadId=1007176

\# ./dst.pl

- Editamos el archivo de sistema que contiene las reglas

**\#** vi /usr/lib/tztab

- Agregamos al final del archivo:

```
<pre style="padding-left:30px;"># Horario normal es PYT con diferencia GMT-4, el horario de verano es PYST con diferencia GMT-3.
PYT4PYST
# Minuto - Hora - Dia - Mes - Año - Dia Semana.
0 23 8-14 4 2010-2038 6 PYT4
0 1  1-7 10 2010-2038 0 PYST3
```

- Definimos la zona horaria

**\#** vi /etc/TIMEZONE

```
<pre style="padding-left:30px;">TZ=PYT4PYST
export TZ
```

- Corroboramos los cambios

**\#** ./dst.pl

## Observación.

Algunos procesos que corren perpetuamente puede requerir un reinicio luego de este cambio. Uno de estos seria el crond.

Y eso es todo, ahora nuestros sistemas contemplan la nueva regla vigente desde este año.

<div id="_mcePaste" style="overflow:hidden;position:absolute;left:-10000px;top:182px;width:1px;height:1px;">```
<pre style="margin-left:2em;">```
ftp://elsie.nci.nih.gov/pub/tz
```
```

</div>