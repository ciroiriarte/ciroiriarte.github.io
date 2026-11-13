---
title: "Guía rápida: Instalación de Sun JRE en SLES11"
description: "Guía rápida para instalar y registrar Sun JRE 7 en SLES11 usando update-alternatives, con todos los slave links relevantes para herramientas como keytool y javaws."
date: 2012-07-18 09:06:20 -0400
permalink: /es/index.php/2012/07/18/quickguide-installing-sun-jre-on-sles11/
lang: es
categories:
  - linux
tags:
  - java
  - sles
deprecated: true
---

Para fines de archivo de Internet: Después de instalar Sun JRE (rpm -Uvh jre-7u5-linux-x64.rpm), la forma correcta de usarlo es configurar los enlaces de alternativas:

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

Si tienes más de un JRE, puedes elegir el nuevo con:

{% highlight shell %}
update-alternatives --config java
{% endhighlight %}
