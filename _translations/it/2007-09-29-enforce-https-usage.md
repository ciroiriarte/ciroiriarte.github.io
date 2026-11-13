---
title: Forzare l'uso di HTTPS
description: "Come forzare HTTPS su Apache2 usando mod_rewrite su SLES9/10, reindirizzando tutto il traffico HTTP verso la porta HTTPS con un semplice file di configurazione."
date: 2007-09-29 05:23:10 -0400
permalink: /it/index.php/2007/09/29/enforce-https-usage/
lang: it
categories:
  - linux
  - security
tags:
  - apache
  - ssl
  - sles
---

Vuoi forzare l'uso di SSL su apache2?, una volta che funziona ti bastano poche righe di mod_rewrite. Nel caso di SLES9/10, crea un file /etc/apache2/conf.d/enforce.conf con il seguente contenuto:

<!--more-->

```apache
# Se indica a apache que todas las conexiones al puerto 80 deben ir al puerto 433, sin excepciones/This forces SSL usage without exceptions
<IfModule !mod_rewrite.c>
LoadModule rewrite_module /usr/lib/apache2-prefork/mod_rewrite.so
</IfModule>
<IfModule mod_rewrite.c>
RewriteEngine on
# La siguiente linea indica la condicion para mod_rewrite / mod_rewrite condition
ReWriteCond %{SERVER_PORT} !^443$
# Regla en caso de que la condicion anterior sea verdadera / rule applied in case the above condition is true
RewriteRule ^/(.*) https://%{HTTP_HOST}/$1 [NC,R,L]
</IfModule>
```

Il percorso esatto del modulo mod_rewrite si trova con `rpm -ql apache2 | grep rewrite`. Ora riavvia apache (`rcapache2 restart`)
