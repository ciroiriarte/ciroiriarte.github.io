---
title: "I/O colgado para siempre al acceder a un dispositivo VDEV"
description: "Cómo resolver procesos con I/O colgado en multipath al acceder a dispositivos VDEV de snapshots de Hitachi VSP, habilitando fail_if_no_path en la configuración de multipath."
date: 2012-07-20 11:01:53 -0400
permalink: /es/index.php/2012/07/20/io-hung-forever-trying-to-access-vdev-device/
lang: es
categories:
  - linux
  - storage-backup
tags:
  - multipath
  - hitachi
---

Configurando snapshots con Hitachi VSP vimos que muchos procesos kpart estaban esperando I/O al intentar acceder a dispositivos VDEV. Eso se debe a la característica queue_if_no_path de multipath.

<!--more-->

La cosa es que es una buena característica: si tienes brechas de tiempo muy pequeñas sin acceso al storage (transición de cluster, alguien jugando con los cables de fibra, etc.) quieres que el I/O se encole y continúe cuando la conexión vuelva a la vida.

Por otro lado, los VDEV aparecen como fallados si los snapshots no están activos, así que la mayor parte del tiempo no quieres encolar las sondas de udev (cientos de procesos en menos de un día en nuestro caso). Para resolverlo puedes habilitar la característica "fail_if_no_path" por LUN, aquí un ejemplo:

{% highlight shell %}
multipath {wwid 350760e9016040b000001040a00002001alias snapdata02LUno_path_retry fail}
{% endhighlight %}

Y no te olvides de reiniciar el daemon de multipath…

Si es necesario, puedes liberar los procesos de I/O pendientes (y devolver error de I/O) con el siguiente comando:

{% highlight shell %}
dmsetup message snapdata02LU 0 "fail_if_no_path"
{% endhighlight %}

Eso es todo…
