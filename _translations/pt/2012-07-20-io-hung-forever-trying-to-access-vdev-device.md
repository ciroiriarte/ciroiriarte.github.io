---
title: "I/O travado para sempre ao acessar um dispositivo VDEV"
description: "Como resolver processos com I/O travado no multipath ao acessar dispositivos VDEV de snapshot do Hitachi VSP, habilitando fail_if_no_path na configuração do multipath."
date: 2012-07-20 11:01:53 -0400
permalink: /pt/index.php/2012/07/20/io-hung-forever-trying-to-access-vdev-device/
lang: pt
categories:
  - linux
  - storage-backup
tags:
  - multipath
  - hitachi
---

Configurando snapshots com Hitachi VSP, vimos que muitos processos kpart estavam esperando por I/O ao tentar acessar dispositivos VDEV. Isso acontece por causa do recurso queue_if_no_path do multipath.

<!--more-->

O ponto é que esse é um bom recurso: se você tem pequenas janelas de tempo sem acesso ao storage (transição de cluster, alguém mexendo nos cabos de fibra, etc.), você quer que o I/O fique em fila e continue quando a conexão voltar à vida.

Por outro lado, os VDEVs aparecem como falhos se os snapshots não estão ativos, então na maior parte do tempo você não quer enfileirar as sondas do udev (centenas de processos em menos de um dia no nosso caso). Para resolver isso, você pode habilitar o recurso "fail_if_no_path" por LUN, aqui vai um exemplo:

{% highlight shell %}
multipath {wwid 350760e9016040b000001040a00002001alias snapdata02LUno_path_retry fail}
{% endhighlight %}

E não se esqueça de reiniciar o daemon do multipath…

Se necessário, você pode liberar os processos de I/O pendentes (retornando erro de I/O) com o seguinte comando:

{% highlight shell %}
dmsetup message snapdata02LU 0 "fail_if_no_path"
{% endhighlight %}

É só isso…
