---
title: Autenticación LDAP con apache2
description: "Guía para configurar autenticación LDAP en Apache2 con mod_auth_ldap en SLES9, incluyendo la configuración del certificado SSL y .htaccess."
date: 2008-02-29 08:59:34 -0300
permalink: /es/index.php/2008/02/29/ldap-authentication-with-apache2/
lang: es
categories:
  - linux
  - security
tags:
  - apache
  - ldap
  - ssl
  - sles
---

Bueno, necesitaba configurar autenticación usando mod_auth_ldap, aquí va el procedimiento.

<!--more-->

Primero debemos asegurarnos de que los módulos necesarios se carguen al iniciar apache2; en SLES9 debemos modificar **/etc/sysconfig/apache2** agregando *"ldap"* y *"auth_ldap"* a la variable **APACHE_MODULES**. Estos módulos vienen integrados en apache2, así que no hace falta instalarlos.

Como estamos usando SSL, necesitaremos el certificado de la CA que firma el certificado del servidor LDAP, y además hay que configurar dos variables: **LDAPTrustedCAType**, que especifica el tipo de certificado (`BASE64_FILE` sirve la mayoría de las veces; la otra opción sería `DER_FILE`) y **LDAPTrustedCA**, que apunta al archivo del certificado.

Creé un archivo llamado *“ldapcert.conf”* en **/etc/apache2/conf.d/** donde las configuro; este es el contenido:

{% highlight apache %}
LDAPTrustedCAType BASE64_FILE
LDAPTrustedCA /etc/ssl/certs/infra.ldap.pem
{% endhighlight %}

Ahora debemos configurar el requisito de autenticación para las páginas deseadas; normalmente esto va en un archivo **.htaccess**, este es el contenido:

{% highlight apache %}
AuthName "My WebApp Auth"
AuthType Basic
AuthLDAPURL "ldaps://server1 server2/ou=people,dc=my,dc=comain,dc=com?uid"
require valid-user
{% endhighlight %}

En nuestro caso tenemos dos servidores de directorio por redundancia; deben ir entre `ldaps://` y `/` separados por espacios; si usas solo uno, se vería algo así como `ldaps://server1/ou=people,dc=my,dc=comain,dc=com?uid`.

En caso de que uses usuario/contraseña para hacer bind al directorio, deberías usar *“AuthLDAPBindDN”* y *“AuthLDAPBindPassword”*; no pude probar esto, así que es solo una nota informativa.

Bueno, ya casi estamos, ahora hay que reiniciar apache; en sles: `rcapache2 restart`.

En los logs deberíamos encontrar estas líneas:

{% highlight text %}
LDAP: Built with OpenLDAP LDAP SDK    <- ldap modules loaded successfully
LDAP: SSL support available           <- CA cert found and read successfully
{% endhighlight %}

Eso es todo…
