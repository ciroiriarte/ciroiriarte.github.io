---
title: Serial Console
description: Quick reference for connecting to equipment via serial console using kermit on Linux.
date: 2006-03-29 01:52:02 -0400
author: Ciro Iriarte
permalink: /index.php/2006/03/29/serial-console/
lang: es
categories:
  - linux
tags:
  - serial-console
---

Para conectarse a un equipo (servidor, pc, etc) con kermit al puerto serial:

{% highlight shell %}
set line /dev/ttyS0  
set speed 115200  
set flow none  
set carrier-watch off  
connect
{% endhighlight %}
