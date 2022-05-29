---
id: 11
title: 'Serial Console'
date: '2006-03-29T01:52:02-04:00'
author: ciroiriarte
layout: post
guid: 'https://cyruspy.wordpress.com/2006/03/29/serial-console/'
permalink: /index.php/2006/03/29/serial-console/
categories:
    - Linux
---

Para conectarse a un equipo (servidor, pc, etc) con kermit al puerto serial:

set line /dev/ttyS0  
set speed 115200  
set flow none  
set carrier-watch off  
connect