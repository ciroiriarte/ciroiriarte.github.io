---
title: Forçar o uso de HTTPS
description: "Como forçar HTTPS no Apache2 usando mod_rewrite no SLES9/10, redirecionando todo o tráfego HTTP para a porta HTTPS com um arquivo de configuração simples."
date: 2007-09-29 05:23:10 -0400
permalink: /pt/index.php/2007/09/29/enforce-https-usage/
lang: pt
categories:
  - linux
  - security
tags:
  - apache
  - ssl
  - sles
---

Quer forçar o uso de SSL no apache2?, depois de deixá-lo funcionando você só precisa de algumas linhas de mod_rewrite. No caso do SLES9/10, crie um arquivo /etc/apache2/conf.d/enforce.conf com o seguinte conteúdo:

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

O caminho exato do módulo mod_rewrite pode ser encontrado com "rpm -ql apache2|grep rewrite". Agora reinicie o apache (rcapache2 restart)
