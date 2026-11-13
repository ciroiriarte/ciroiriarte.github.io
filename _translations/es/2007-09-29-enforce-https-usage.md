---
title: Forzar el uso de HTTPS
description: "Cómo forzar HTTPS en Apache2 usando mod_rewrite en SLES9/10, redirigiendo todo el tráfico HTTP al puerto HTTPS con un sencillo archivo de configuración."
date: 2007-09-29 05:23:10 -0400
permalink: /es/index.php/2007/09/29/enforce-https-usage/
lang: es
categories:
  - linux
  - security
tags:
  - apache
  - ssl
  - sles
---

¿Quieres forzar el uso de SSL en apache2?, una vez que lo tienes funcionando solo necesitas unas pocas líneas de mod_rewrite. En el caso de SLES9/10, crea un archivo /etc/apache2/conf.d/enforce.conf con el siguiente contenido:

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

La ruta exacta del módulo mod_rewrite se puede encontrar con `rpm -ql apache2 | grep rewrite`. Ahora reinicia apache (`rcapache2 restart`)
