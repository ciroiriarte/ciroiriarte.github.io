---
title: "Quickguide: installare Sun JRE su SLES11"
description: "Guida rapida per installare e registrare Sun JRE 7 su SLES11 usando update-alternatives, con tutti gli slave link rilevanti per strumenti come keytool e javaws."
date: 2012-07-18 09:06:20 -0400
permalink: /it/index.php/2012/07/18/quickguide-installing-sun-jre-on-sles11/
lang: it
categories:
  - linux
tags:
  - java
  - sles
deprecated: true
---

Per scopi di archiviazione su Internet: dopo aver installato Sun JRE (rpm -Uvh jre-7u5-linux-x64.rpm), il modo corretto di usarlo è configurare i link delle alternatives:

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

Se hai più di una JRE, puoi scegliere quella nuova con:

{% highlight shell %}
update-alternatives --config java
{% endhighlight %}
