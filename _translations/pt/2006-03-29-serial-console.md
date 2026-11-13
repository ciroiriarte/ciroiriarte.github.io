---
title: Console serial
description: Referência rápida para conectar a equipamentos via console serial usando kermit no Linux.
date: 2006-03-29 01:52:02 -0400
permalink: /pt/index.php/2006/03/29/serial-console/
lang: pt
categories:
  - linux
tags:
  - serial-console
---

Para conectar a um equipamento (servidor, pc, etc.) com kermit pela porta serial:

{% highlight shell %}
set line /dev/ttyS0  
set speed 115200  
set flow none  
set carrier-watch off  
connect
{% endhighlight %}
