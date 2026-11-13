---
title: "I/O bloccato per sempre durante l'accesso a un dispositivo VDEV"
description: "Come risolvere i processi con I/O bloccato in multipath durante l'accesso ai dispositivi VDEV di snapshot Hitachi VSP, abilitando fail_if_no_path nella configurazione di multipath."
date: 2012-07-20 11:01:53 -0400
permalink: /it/index.php/2012/07/20/io-hung-forever-trying-to-access-vdev-device/
lang: it
categories:
  - linux
  - storage-backup
tags:
  - multipath
  - hitachi
---

Configurando gli snapshot con Hitachi VSP abbiamo visto che molti processi kpart restavano in attesa di I/O cercando di accedere ai dispositivi VDEV. Il motivo è la funzionalità queue_if_no_path di multipath.

<!--more-->

Il fatto è che è una buona funzionalità: se hai piccolissimi intervalli di tempo senza accesso allo storage (transizione del cluster, qualcuno che smanetta con i cavi in fibra, ecc.) vuoi che l'I/O venga messo in coda e riprenda quando la connessione torna in vita.

D'altra parte, i VDEV risultano in errore se gli snapshot non sono attivi, quindi per la maggior parte del tempo non vuoi mettere in coda le sonde di udev (centinaia di processi in meno di un giorno, nel nostro caso). Per risolvere puoi abilitare la funzionalità "fail_if_no_path" per singola LUN, ecco un esempio:

{% highlight shell %}
multipath {wwid 350760e9016040b000001040a00002001alias snapdata02LUno_path_retry fail}
{% endhighlight %}

E non dimenticare di riavviare il daemon multipath…

Se serve, puoi liberare i processi con I/O in sospeso (restituendo un errore di I/O) con il comando seguente:

{% highlight shell %}
dmsetup message snapdata02LU 0 "fail_if_no_path"
{% endhighlight %}

Tutto qui…
