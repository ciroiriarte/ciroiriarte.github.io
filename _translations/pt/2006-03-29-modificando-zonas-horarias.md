---
title: Modificando fusos horários
description: "Guia para modificar arquivos de fuso horário no Linux usando zic e o banco de dados Olson, com um exemplo para o Paraguai."
date: 2006-03-29 01:50:01 -0400
permalink: /pt/index.php/2006/03/29/modificando-zonas-horarias/
lang: pt
categories:
  - linux
tags:
  - timezone
---

## Intro {#intro}

Os arquivos com informações sobre os fusos horários e o popular “daylight saving” ficam em /usr/share/zoneinfo. Eles podem ser consultados com:

{% highlight shell %}
zdump -v "archivo"
{% endhighlight %}

No nosso caso é muito comum que mudem as datas em que ocorre a mudança de horário; para corrigir isso, é preciso recompilar esses arquivos depois de modificá-los, o que se faz com o comando zic.

<!--more-->

As definições de zonas são baixadas de [ftp://elsie.nci.nih.gov/pub/](ftp://elsie.nci.nih.gov/pub/)

## Procedimento (exemplo para o Paraguai) {#procedimiento-ejemplo-para-paraguay}

{% highlight shell %}

# Realizar copia de seguridad  
cp -rp /usr/share/zoneinfo{,.$(date +%Y%m%d)}

# Obtener source:  
mkdir -p /tmp/tzdata && cd /tmp/tzdata  
wget 'ftp://elsie.nci.nih.gov/pub/tzdata*.tar.gz'

# Realizar modificacion
tar xvzf tzdata*
vi southamerica

# Compilar  
/usr/sbin/zic southamerica

# Definir zona horaria  
cp /usr/share/zoneinfo/America/Asuncion /etc/localtime
{% endhighlight %}
