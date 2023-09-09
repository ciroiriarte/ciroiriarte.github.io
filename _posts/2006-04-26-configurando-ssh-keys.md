---
id: 13
title: 'Configurando SSH keys'
date: '2006-04-26T02:05:42-04:00'
author: ciroiriarte
layout: post
guid: 'https://cyruspy.wordpress.com/2006/04/26/configurando-ssh-keys/'
permalink: /index.php/2006/04/26/configurando-ssh-keys/
categories:
    - Linux
---

Para dejar de lado la autenticacion por contraseña se usan keys DSA. Seguir los siguientes pasos:

Crear el par publico/privado de llaves (keys), las misma son puestas en "~/.ssh"

{% highlight shell %}
usuario1@sshclient:~$ ssh-keygen -t dsa
{% endhighlight %}

Copiar llave publica al otro host:  

{% highlight shell %}
usuario1@sshclient:~$ cat ~/.ssh/id\_dsa.pub | ssh usuario2@sshserver "cat &gt;&gt; .ssh/authorized\_keys"
{% endhighlight %}

Cambiar permisos:

{% highlight shell %}
usuario1@sshclient:~$ ssh usuario2@sshserver chmod 600 .ssh/authorized\_keys
{% endhighlight %}