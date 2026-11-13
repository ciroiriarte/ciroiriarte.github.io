---
title: Serial Console
description: Quick reference for connecting to equipment via serial console using kermit on Linux.
date: 2006-03-29 01:52:02 -0400
permalink: /en/index.php/2006/03/29/serial-console/
lang: en
categories:
  - linux
tags:
  - serial-console
---

To connect to a device (server, PC, etc.) over the serial port with kermit:

{% highlight shell %}
set line /dev/ttyS0  
set speed 115200  
set flow none  
set carrier-watch off  
connect
{% endhighlight %}
