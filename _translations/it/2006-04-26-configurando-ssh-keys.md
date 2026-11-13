---
title: Configurare le chiavi SSH
description: "Guida passo passo per configurare l'autenticazione SSH con chiavi DSA su Linux, dalla generazione della coppia di chiavi alla configurazione sull'host remoto."
date: 2006-04-26 02:05:42 -0400
permalink: /it/index.php/2006/04/26/configurando-ssh-keys/
lang: it
categories:
  - linux
  - security
tags:
  - ssh
deprecated: true
---

Per abbandonare l'autenticazione con password si usano le chiavi DSA. Segui questi passi:

Crea la coppia di chiavi pubblica/privata, che vengono messe in "~/.ssh"

{% highlight shell %}
usuario1@sshclient:~$ ssh-keygen -t dsa
{% endhighlight %}

Copia la chiave pubblica sull'altro host:  

{% highlight shell %}
usuario1@sshclient:~$ cat ~/.ssh/id_dsa.pub | ssh usuario2@sshserver "cat >> .ssh/authorized_keys"
{% endhighlight %}

Cambia i permessi:

{% highlight shell %}
usuario1@sshclient:~$ ssh usuario2@sshserver chmod 600 .ssh/authorized_keys
{% endhighlight %}
