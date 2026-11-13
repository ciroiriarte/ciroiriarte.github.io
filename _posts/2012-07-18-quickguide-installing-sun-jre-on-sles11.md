---
title: "Quickguide: Installing Sun JRE on SLES11"
description: "Quick guide for installing and registering Sun JRE 7 on SLES11 using update-alternatives, with all relevant slave links for tools like keytool and javaws."
date: 2012-07-18 09:06:20 -0400
author: Ciro Iriarte
permalink: /index.php/2012/07/18/quickguide-installing-sun-jre-on-sles11/
lang: en
categories:
  - linux
tags:
  - java
  - sles
deprecated: true
---

For Internet archiving purposes: After installing Sun JRE (rpm -Uvh jre-7u5-linux-x64.rpm), the properly way to use it is setting up the alternatives links:

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

If you have more than one JRE, you can choose the new one with:

{% highlight shell %}
update-alternatives --config java
{% endhighlight %}
