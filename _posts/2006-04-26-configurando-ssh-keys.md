---
title: Configurando SSH keys
description: "Guía paso a paso para configurar autenticación SSH con llaves DSA en Linux, desde la generación del par de llaves hasta la configuración en el host remoto."
date: 2006-04-26 02:05:42 -0400
author: Ciro Iriarte
permalink: /index.php/2006/04/26/configurando-ssh-keys/
lang: es
categories:
  - linux
  - security
tags:
  - ssh
deprecated: true
---

Para dejar de lado la autenticacion por contraseña se usan keys DSA. Seguir los siguientes pasos:

Crear el par publico/privado de llaves (keys), las misma son puestas en "~/.ssh"

{% highlight shell %}
usuario1@sshclient:~$ ssh-keygen -t dsa
{% endhighlight %}

Copiar llave publica al otro host:  

{% highlight shell %}
usuario1@sshclient:~$ cat ~/.ssh/id_dsa.pub | ssh usuario2@sshserver "cat >> .ssh/authorized_keys"
{% endhighlight %}

Cambiar permisos:

{% highlight shell %}
usuario1@sshclient:~$ ssh usuario2@sshserver chmod 600 .ssh/authorized_keys
{% endhighlight %}
