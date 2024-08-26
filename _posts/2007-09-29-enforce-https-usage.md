---
id: 14
title: 'Enforce HTTPS usage'
date: '2007-09-29T05:23:10-04:00'
author: Ciro Iriarte
layout: post
guid: 'http://cyruspy.wordpress.com/2007/09/29/enforce-https-usage/'
permalink: /index.php/2007/09/29/enforce-https-usage/
categories:
    - apache
    - Linux
    - SLES
tags:
    - 'ssl apache2 mod_rewrite'
---

Want to enforce SSL usage on apache2?, after having it working you only need a few mod\_rewrite lines. In the case of SLES9/10, create a file /etc/apache2/conf.d/enforce.conf with the following content:

\# Se indica a apache que todas las conexiones al puerto 80 deben ir al puerto 433, sin excepciones/This forces SSL usage without exceptions  
&lt;IfModule !mod\_rewrite.c&gt;  
LoadModule rewrite\_module /usr/lib/apache2-prefork/mod\_rewrite.so  
&lt;/IfModule&gt;  
&lt;IfModule mod\_rewrite.c&gt;  
RewriteEngine on  
\# La siguiente linea indica la condicion para mod\_rewrite / mod\_rewrite condition  
ReWriteCond %{SERVER\_PORT} !^443$  
\# Regla en caso de que la condicion anterior sea verdadera / rule applied in case the above condition is true  
RewriteRule ^/(.\*) https://%{HTTP\_HOST}/$1 \[NC,R,L\]  
&lt;/IfModule&gt;

The exact path to mod\_rewrite module can be found with “rpm -ql apache2|grep rewrite”. Now restart apache (rcapache2 restart)