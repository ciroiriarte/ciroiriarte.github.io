---
title: Console seriale
description: Riferimento rapido per collegarsi ad apparati tramite console seriale con kermit su Linux.
date: 2006-03-29 01:52:02 -0400
permalink: /it/index.php/2006/03/29/serial-console/
lang: it
categories:
  - linux
tags:
  - serial-console
---

Per collegarsi a un apparato (server, pc, ecc.) con kermit tramite la porta seriale:

{% highlight shell %}
set line /dev/ttyS0  
set speed 115200  
set flow none  
set carrier-watch off  
connect
{% endhighlight %}
