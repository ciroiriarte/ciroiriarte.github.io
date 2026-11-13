---
title: Setting up SSH keys
description: "Step-by-step guide to setting up SSH authentication with DSA keys on Linux, from generating the key pair to configuring the remote host."
date: 2006-04-26 02:05:42 -0400
permalink: /en/index.php/2006/04/26/configurando-ssh-keys/
lang: en
categories:
  - linux
  - security
tags:
  - ssh
deprecated: true
---

To get rid of password authentication, use DSA keys. Follow these steps:

Create the public/private key pair, they are placed in "~/.ssh"

{% highlight shell %}
usuario1@sshclient:~$ ssh-keygen -t dsa
{% endhighlight %}

Copy the public key to the other host:  

{% highlight shell %}
usuario1@sshclient:~$ cat ~/.ssh/id_dsa.pub | ssh usuario2@sshserver "cat >> .ssh/authorized_keys"
{% endhighlight %}

Change permissions:

{% highlight shell %}
usuario1@sshclient:~$ ssh usuario2@sshserver chmod 600 .ssh/authorized_keys
{% endhighlight %}
