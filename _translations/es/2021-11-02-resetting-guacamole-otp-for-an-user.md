---
title: "Restableciendo el OTP de Guacamole para un usuario"
description: "Cómo restablecer el enrolamiento TOTP de un usuario de Guacamole respaldado por FreeIPA (LDAP) y MySQL."
date: 2021-11-02 10:19:37 -0300
permalink: /es/index.php/2021/11/02/resetting-guacamole-otp-for-an-user/
lang: es
categories:
  - security
tags:
  - guacamole
  - mfa
---

He implementado Guacamole para acceso remoto; por ahora usa el módulo OTP integrado. En el futuro quizás migre a LemonLDAP o Keycloak para 2FA, pero por ahora la solución es suficientemente buena y funciona sin configuración después de instalar el módulo 🙂

{% include image.html url="/assets/img/2021-11-02-guacamole-totp-enroll.png" description="Pantalla de enrolamiento multifactor (TOTP) de Guacamole" width=625 height=706 %}

Mi configuración en particular obtiene los usuarios de FreeIPA mediante LDAP, pero también usa MySQL como complemento para manejar las definiciones de conexiones y cosas como la información del plugin de OTP.

De vez en cuando, un usuario necesita volver a enrolar un dispositivo porque el original fue robado o reiniciado. Hice una búsqueda rápida, pero no encontré una opción limpia/fácil para restablecerlo desde la GUI en la versión 1.3.0.


Como solución rápida (no quiero tener que replantearme esto cada vez que un usuario lo necesite), creé un script sencillo que hace el trabajo por mí.

Todo lo que necesitas hacer es configurar la conexión a tu base MySQL en ~/.my.cnf y obtener el script desde aquí:

<https://github.com/ciroiriarte/sysadmin-scripts/blob/main/guacamole-reset-user-otp.sh>

En la mayoría de las máquinas Linux, puedes copiarlo a ~/bin/.

{% highlight shell %}
mkdir ~/bin
cd ~/bin
wget https://raw.githubusercontent.com/ciroiriarte/sysadmin-scripts/main/guacamole-reset-user-otp.sh
chmod +x guacamole-reset-user-otp.sh
{% endhighlight %}

Si ejecutas el script sin opciones, te mostrará la sintaxis

{% highlight shell %}
guacamole-reset-user-otp.sh
Usage: /home/me/bin/guacamole-reset-user-otp.sh <username>
      /home/me/bin/guacamole-reset-user-otp.sh ciro.iriarte
{% endhighlight %}

Y la ejecución debería ser tan simple como:

{% highlight shell %}
guacamole-reset-user-otp.sh the.user
{% endhighlight %}
