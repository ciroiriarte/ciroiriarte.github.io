---
title: Configurando chaves SSH
description: "Guia passo a passo para configurar autenticação SSH com chaves DSA no Linux, da geração do par de chaves até a configuração no host remoto."
date: 2006-04-26 02:05:42 -0400
permalink: /pt/index.php/2006/04/26/configurando-ssh-keys/
lang: pt
categories:
  - linux
  - security
tags:
  - ssh
deprecated: true
---

Para abandonar a autenticação por senha, usam-se chaves DSA. Siga estes passos:

Crie o par de chaves pública/privada, que são colocadas em "~/.ssh"

{% highlight shell %}
usuario1@sshclient:~$ ssh-keygen -t dsa
{% endhighlight %}

Copie a chave pública para o outro host:  

{% highlight shell %}
usuario1@sshclient:~$ cat ~/.ssh/id_dsa.pub | ssh usuario2@sshserver "cat >> .ssh/authorized_keys"
{% endhighlight %}

Altere as permissões:

{% highlight shell %}
usuario1@sshclient:~$ ssh usuario2@sshserver chmod 600 .ssh/authorized_keys
{% endhighlight %}
