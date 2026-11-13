---
title: "Quickguide: Instalando o Sun JRE no SLES11"
description: "Guia rápido para instalar e registrar o Sun JRE 7 no SLES11 usando update-alternatives, com todos os slave links relevantes para ferramentas como keytool e javaws."
date: 2012-07-18 09:06:20 -0400
permalink: /pt/index.php/2012/07/18/quickguide-installing-sun-jre-on-sles11/
lang: pt
categories:
  - linux
tags:
  - java
  - sles
deprecated: true
---

Para fins de arquivamento na Internet: depois de instalar o Sun JRE (rpm -Uvh jre-7u5-linux-x64.rpm), a forma correta de usá-lo é configurar os links de alternatives:

{% highlight shell %}
update-alternatives --install java java /usr/java/jre1.7.0_05/bin/java 60 \
--slave jre jre /usr/java/jre1.7.0_05 \ 
--slave rmiregistry rmiregistry /usr/java/jre1.7.0_05/bin/rmiregistry \
--slave tnameserv tnameserv /usr/java/jre1.7.0_05/bin/tnameserv \
--slave rmid rmid /usr/java/jre1.7.0_05/bin/rmid \
--slave ControlPanel ControlPanel /usr/java/jre1.7.0_05/bin/ControlPanel \
--slave policytool policytool /usr/java/jre1.7.0_05/bin/policytool \
--slave keytool keytool /usr/java/jre1.7.0_05/bin/keytool \
--slave javaws javaws /usr/java/jre1.7.0_05/bin/javaws
{% endhighlight %}

Se você tiver mais de um JRE, pode escolher o novo com:

{% highlight shell %}
update-alternatives --config java
{% endhighlight %}
